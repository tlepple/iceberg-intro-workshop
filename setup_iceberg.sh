#!/bin/bash

##########################################################################################
#  make sure some utils are installed in the OS
#########################################################################################
sudo apt-get install wget curl -y

##########################################################################################
#  #  going to install a specific version of postgresql (version 14)
##########################################################################################
apt policy postgresql

##########################################################################################
#  install the pgp key for this version:
##########################################################################################
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt update

sudo apt install postgresql-14 -y

sudo systemctl enable postgresql

##########################################################################################
#  backup the orig conf file
##########################################################################################
sudo cp /etc/postgresql/14/main/postgresql.conf /etc/postgresql/14/main/postgresql.conf.orig

##########################################################################################
## Allow listeners from any host
##########################################################################################
sudo sed -e 's,#listen_addresses = \x27localhost\x27,listen_addresses = \x27*\x27,g' -i /etc/postgresql/14/main/postgresql.conf

##########################################################################################
## Increase number of connections
##########################################################################################
sudo sed -e 's,max_connections = 100,max_connections = 300,g' -i /etc/postgresql/14/main/postgresql.conf

##########################################################################################
#  create a new pg_hba.conf
##########################################################################################
sudo mv /etc/postgresql/14/main/pg_hba.conf /etc/postgresql/14/main/pg_hba.conf.orig

cat <<EOF > pg_hba.conf
  # TYPE  DATABASE        USER            ADDRESS                 METHOD
  local   all             all                                     peer
  host    datagen         datagen        0.0.0.0/0                md5
  host    icecatalog      icecatalog     0.0.0.0/0                md5
EOF

##########################################################################################
#   set owner and permissions
##########################################################################################
sudo mv pg_hba.conf /etc/postgresql/14/main/pg_hba.conf
sudo chown postgres:postgres /etc/postgresql/14/main/pg_hba.conf
sudo chmod 600 /etc/postgresql/14/main/pg_hba.conf

##########################################################################################
# Restart Postgresql
##########################################################################################
sudo systemctl restart postgresql

##########################################################################################
#    Create a DDL file for icecatalog database
##########################################################################################

cat <<EOF > ~/create_ddl_icecatalog.sql
CREATE ROLE icecatalog LOGIN PASSWORD 'supersecret1';
CREATE DATABASE icecatalog OWNER icecatalog ENCODING 'UTF-8';
ALTER USER icecatalog WITH SUPERUSER;
ALTER USER icecatalog WITH CREATEDB;
CREATE SCHEMA icecatalog;
EOF

##########################################################################################
## Run the sql file to create the schema for all DB’s
##########################################################################################
sudo -u postgres psql < ~/create_ddl_icecatalog.sql

##########################################################################################
#  let's install a postgresql client only that we can use to test access to postgresql server on the red panda host:
##########################################################################################
sudo apt install postgresql-client  -y

##########################################################################################
#  Install Java 11:echo
##########################################################################################
sudo apt install openjdk-11-jdk -y

##########################################################################################
#  Install Maven - not sure if needed:
##########################################################################################
sudo apt install maven -y

#########################################################################################
#  download apache spark standalone
##########################################################################################
wget https://dlcdn.apache.org/spark/spark-3.3.1/spark-3.3.1-bin-hadoop3.tgz

tar -xzvf spark-3.3.1-bin-hadoop3.tgz

sudo mv spark-3.3.1-bin-hadoop3/ /opt/spark

##########################################################################################
#  install aws cli
##########################################################################################
sudo apt install awscli -y

##########################################################################################
#  install mlocate
##########################################################################################
sudo apt install -y mlocate

##########################################################################################
#  jdbc for postgres:  download
##########################################################################################
wget https://jdbc.postgresql.org/download/postgresql-42.5.1.jar

sudo cp postgresql-42.5.1.jar /opt/spark/jars/

##########################################################################################
# need some aws jars:
##########################################################################################
wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.19.19/bundle-2.19.19.jar

sudo cp bundle-2.19.19.jar /opt/spark/jars/


wget https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.19.19/url-connection-client-2.19.19.jar
cp url-connection-client-2.19.19.jar /opt/spark/jars/

##########################################################################################
#  need iceberg spark runtime to
##########################################################################################
wget https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.3_2.12/1.1.0/iceberg-spark-runtime-3.3_2.12-1.1.0.jar

cp ~/iceberg-spark-runtime-3.3_2.12-1.1.0.jar /opt/spark/jars/


##########################################################################################
#  download minio debian package
##########################################################################################
wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20230112020616.0.0_amd64.deb -O minio.deb

##########################################################################################
#   install minio
##########################################################################################
sudo dpkg -i minio.deb


##########################################################################################
#  create directory for minio data to be stored
##########################################################################################
sudo mkdir -p /opt/app/minio/data

sudo groupadd -r minio-user
sudo useradd -M -r -g minio-user minio-user

# grant permission to this directory to minio-user
sudo chown -R minio-user:minio-user /opt/app/minio/

##########################################################################################
#  create an enviroment variable file for minio
##########################################################################################

cat <<EOF > ~/minio.properties
# MINIO_ROOT_USER and MINIO_ROOT_PASSWORD sets the root account for the MinIO server.
# This user has unrestricted permissions to perform S3 and administrative API operations on any resource in the deployment.
# Omit to use the default values 'minioadmin:minioadmin'.
# MinIO recommends setting non-default values as a best practice, regardless of environment

#MINIO_ROOT_USER=myminioadmin
#MINIO_ROOT_PASSWORD=minio-secret-key-change-me

MINIO_ROOT_USER=minioroot
MINIO_ROOT_PASSWORD=supersecret1

# MINIO_VOLUMES sets the storage volume or path to use for the MinIO server.

#MINIO_VOLUMES="/mnt/data"
MINIO_VOLUMES="/opt/app/minio/data"

# MINIO_SERVER_URL sets the hostname of the local machine for use with the MinIO Server
# MinIO assumes your network control plane can correctly resolve this hostname to the local machine

# Uncomment the following line and replace the value with the correct hostname for the local machine.

#MINIO_SERVER_URL="http://minio.example.net"
EOF

##########################################################################################
#   move this file to proper directory
##########################################################################################
sudo mv ~/minio.properties /etc/default/minio

sudo chown root:root /etc/default/minio


##########################################################################################
#  start the minio server:
##########################################################################################
sudo systemctl start minio.service


##########################################################################################
#  Install the MinIO Client on this server host:
##########################################################################################
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o $HOME/minio-binaries/mc

chmod +x $HOME/minio-binaries/mc
export PATH=$PATH:$HOME/minio-binaries/

##########################################################################################
#  create an alias on this host for the minio cli (using the minio root credentials)
##########################################################################################
mc alias set local http://127.0.0.1:9000 minioroot supersecret1

##########################################################################################
#  lets create a user for iceberg metadata & tables using the alias we just set
##########################################################################################
mc admin user add local icebergadmin supersecret1!

##########################################################################################
# need to add the 'readwrite' policy to this new user:
##########################################################################################
mc admin policy set local readwrite user=icebergadmin

##########################################################################################
#  create a new alias for this user:
##########################################################################################
mc alias set icebergadmin http://127.0.0.1:9000 icebergadmin supersecret1!

##########################################################################################
# create new 'Access Keys' for this user and redirect output to a file for automation later
##########################################################################################
mc admin user svcacct add icebergadmin icebergadmin >> ~/minio-output.properties

##########################################################################################
#  create a bucket as user icebergadmin for our iceberg data
##########################################################################################
mc mb icebergadmin/iceberg-data icebergadmin

##########################################################################################
#  let's reformat the output of keys from an earlier step
##########################################################################################
sed -i "s/Access Key: /access_key=/g" ~/minio-output.properties
sed -i "s/Secret Key: /secret_key=/g" ~/minio-output.properties


##########################################################################################
#   let's  read the update file into memory to use these values to set aws configure
##########################################################################################
. ./minio-output.properties

##########################################################################################
#  let's set up aws configure files from code (this is using the minio credentials) - The default region doesn't get used in minio
##########################################################################################
aws configure set aws_access_key_id $access_key
aws configure set aws_secret_access_key $secret_key
aws configure set default.region us-east-1

##########################################################################################
#  let's test by listing our buckets:
##########################################################################################
aws --endpoint-url http://127.0.0.1:9000 s3 ls

##########################################################################################
#   create a directory for spark events & logs
##########################################################################################
mkdir -p /opt/spark/logs
mkdir -p /opt/spark/spark-events
mkdir -p /opt/spark/input

##########################################################################################
#  Create a json records file to be used in a lab
##########################################################################################

cat <<EOF > /opt/spark/input/customers.json
{"last_name": "Thompson", "first_name": "Brenda", "street_address": "321 Nicole Ports Suite 204", "city": "South Lisachester", "state": "AS", "zip_code": "89409", "email": "wmoran@example.net", "home_phone": "486.884.6221x4431", "mobile": "(290)274-1564", "ssn": "483-79-5404", "job_title": "Housing manager/officer", "create_date": "2022-12-25 01:10:43", "cust_id": 10}
{"last_name": "Anderson", "first_name": "Jennifer", "street_address": "1392 Cervantes Isle", "city": "Adrianaton", "state": "IN", "zip_code": "15867", "email": "michaeltodd@example.com", "home_phone": "939-630-6773", "mobile": "904.337.2023x17453", "ssn": "583-07-6994", "job_title": "Clinical embryologist", "create_date": "2022-12-03 04:50:07", "cust_id": 11}
{"last_name": "Jefferson", "first_name": "William", "street_address": "543 Matthew Courts", "city": "South Nicholaston", "state": "WA", "zip_code": "17687", "email": "peterhouse@example.net", "home_phone": "+1-599-587-9051x2899", "mobile": "(915)689-1450", "ssn": "792-52-6700", "job_title": "Land", "create_date": "2022-11-28 08:17:10", "cust_id": 12}
{"last_name": "Romero", "first_name": "Jack", "street_address": "5929 Karen Ridges", "city": "Lake Richardburgh", "state": "OR", "zip_code": "78947", "email": "michellemitchell@example.net", "home_phone": "(402)664-1399x71255", "mobile": "450.580.6817x043", "ssn": "216-24-7271", "job_title": "Engineer, building services", "create_date": "2022-12-11 19:09:30", "cust_id": 13}
{"last_name": "Johnson", "first_name": "Robert", "street_address": "4313 Adams Islands", "city": "Tammybury", "state": "UT", "zip_code": "07361", "email": "morrischristopher@example.com", "home_phone": "(477)888-9999", "mobile": "220-403-9274x9709", "ssn": "012-26-8650", "job_title": "Rural practice surveyor", "create_date": "2022-12-08 05:28:56", "cust_id": 14}
EOF

##########################################################################################
#  Create another json records file to be used in a Merge Query in a lab
##########################################################################################

cat <<EOF > /opt/spark/input/update_customers.json
{"last_name": "Rogers", "first_name": "Caitlyn", "street_address": "37761 Robert Center Apt. 743", "city": "Port Matthew", "state": "MS", "zip_code": "70534", "email": "pamelacooper@example.net", "home_phone": "726-856-7295x731", "mobile": "+1-423-331-9415x66671", "ssn": "718-18-3807", "job_title": "Merchandiser, retail", "create_date": "2022-12-16 03:19:35", "cust_id": 10}
{"last_name": "Williams", "first_name": "Brittany", "street_address": "820 Lopez Vista", "city": "Jordanland", "state": "NM", "zip_code": "02887", "email": "stephendawson@example.org", "home_phone": "(149)065-2341x761", "mobile": "(353)203-7938x325", "ssn": "304-90-3213", "job_title": "English as a second language teacher", "create_date": "2022-12-04 23:29:48", "cust_id": 11}
{"last_name": "Gordon", "first_name": "Victor", "street_address": "01584 Hernandez Ramp Suite 822", "city": "Smithmouth", "state": "VI", "zip_code": "88806", "email": "holly51@example.com", "home_phone": "707-269-9666x8446", "mobile": "+1-868-584-1822", "ssn": "009-27-3700", "job_title": "Ergonomist", "create_date": "2022-12-22 18:03:13", "cust_id": 12}
{"last_name": "Martinez", "first_name": "Shelby", "street_address": "715 Benitez Plaza", "city": "Patriciaside", "state": "MT", "zip_code": "70724", "email": "tiffanysmith@example.com", "home_phone": "854.472.8345", "mobile": "+1-187-913-4579x115", "ssn": "306-94-1636", "job_title": "Private music teacher", "create_date": "2022-11-27 16:10:42", "cust_id": 13}
{"last_name": "Bridges", "first_name": "Corey", "street_address": "822 Kaitlyn Haven Apt. 314", "city": "Port Elizabeth", "state": "OH", "zip_code": "58802", "email": "rosewayne@example.org", "home_phone": "001-809-935-9112x17961", "mobile": "+1-732-477-7876x9314", "ssn": "801-31-5673", "job_title": "Scientist, research (maths)", "create_date": "2022-12-11 23:29:52", "cust_id": 14}
{"last_name": "Rocha", "first_name": "Benjamin", "street_address": "294 William Skyway", "city": "Fowlerville", "state": "WA", "zip_code": "75495", "email": "fwhite@example.com", "home_phone": "001-476-468-4403x364", "mobile": "4731036956", "ssn": "571-78-6278", "job_title": "Probation officer", "create_date": "2022-12-10 07:39:35", "cust_id": 15}
{"last_name": "Lawrence", "first_name": "Jonathan", "street_address": "4610 Kelly Road Suite 333", "city": "Michaelfort", "state": "PR", "zip_code": "03033", "email": "raymisty@example.com", "home_phone": "936.011.1602x5883", "mobile": "(577)016-2546x30390", "ssn": "003-05-2317", "job_title": "Dancer", "create_date": "2022-11-27 23:44:14", "cust_id": 16}
{"last_name": "Taylor", "first_name": "Thomas", "street_address": "51884 Kelsey Ridges Apt. 973", "city": "Lake Morgan", "state": "RI", "zip_code": "36056", "email": "vanggary@example.net", "home_phone": "541-784-5497x32009", "mobile": "+1-337-857-9219x83198", "ssn": "133-61-4337", "job_title": "Town planner", "create_date": "2022-12-07 12:33:45", "cust_id": 17}
{"last_name": "Williamson", "first_name": "Jeffrey", "street_address": "6094 Powell Passage", "city": "Stevenland", "state": "VT", "zip_code": "88479", "email": "jwallace@example.com", "home_phone": "4172910794", "mobile": "494.361.3094x223", "ssn": "512-84-0907", "job_title": "Clinical cytogeneticist", "create_date": "2022-12-13 16:58:43", "cust_id": 18}
{"last_name": "Mccullough", "first_name": "Joseph", "street_address": "7329 Santiago Point Apt. 070", "city": "Reedland", "state": "MH", "zip_code": "85316", "email": "michellecain@example.com", "home_phone": "(449)740-1390", "mobile": "(663)381-3306x19170", "ssn": "605-84-9744", "job_title": "Seismic interpreter", "create_date": "2022-12-05 05:33:56", "cust_id": 19}
{"last_name": "Kirby", "first_name": "Evan", "street_address": "95959 Brown Rue Apt. 657", "city": "Lake Vanessa", "state": "MH", "zip_code": "92042", "email": "tayloralexandra@example.org", "home_phone": "342-317-5803", "mobile": "185-084-4719x39341", "ssn": "264-14-4935", "job_title": "Interpreter", "create_date": "2022-12-20 14:23:43", "cust_id": 20}
{"last_name": "Pittman", "first_name": "Teresa", "street_address": "3249 Danielle Parks Apt. 472", "city": "East Ryan", "state": "ME", "zip_code": "33108", "email": "hamiltondanielle@example.org", "home_phone": "+1-814-789-0109x88291", "mobile": "(749)434-0916", "ssn": "302-61-5936", "job_title": "Medical physicist", "create_date": "2022-12-26 05:14:24", "cust_id": 21}
{"last_name": "Byrd", "first_name": "Alicia", "street_address": "1232 Jenkins Pine Apt. 472", "city": "Woodton", "state": "NC", "zip_code": "82330", "email": "shelly47@example.net", "home_phone": "001-930-450-7297x258", "mobile": "+1-968-526-2756x661", "ssn": "656-69-9593", "job_title": "Therapist, art", "create_date": "2022-12-17 18:20:51", "cust_id": 22}
{"last_name": "Ellis", "first_name": "Kathleen", "street_address": "935 Kristina Club", "city": "East Maryton", "state": "AK", "zip_code": "86759", "email": "jacksonkaren@example.com", "home_phone": "001-089-194-5982x828", "mobile": "127.892.8518", "ssn": "426-13-9463", "job_title": "English as a foreign language teacher", "create_date": "2022-12-08 04:01:44", "cust_id": 23}
{"last_name": "Lee", "first_name": "Tony", "street_address": "830 Elizabeth Mill Suite 184", "city": "New Heather", "state": "UT", "zip_code": "59612", "email": "vmayo@example.net", "home_phone": "001-593-666-0198", "mobile": "060.108.7218", "ssn": "048-20-6647", "job_title": "Civil engineer, consulting", "create_date": "2022-12-24 17:10:32", "cust_id": 24}
EOF

##########################################################################################
#  Let's add some transactions for these customers for a lab
##########################################################################################
cat <<EOF > /opt/spark/input/transactions.json
{'transact_id': '586fef8b-00da-4216-832a-a0eb5211b54a', 'category': 'purple', 'barcode': '4541397840276', 'item_desc': 'Than explain cover.', 'amount': 50.63, 'transaction_date': '2023-01-08 00:11:25', 'cust_id': 10}
{'transact_id': 'e8809684-7997-4ccf-96df-02fd57ca9d6f', 'category': 'green', 'barcode': '2308832642138', 'item_desc': 'Necessary body oil.', 'amount': 95.37, 'transaction_date': '2023-01-23 17:23:04', 'cust_id': 10}
{'transact_id': '18bb3472-56c0-48e3-a599-72f54a706b58', 'category': 'teal', 'barcode': '1644304420912', 'item_desc': 'Recent property act five issue physical.', 'amount': 9.71, 'transaction_date': '2023-01-18 18:12:44', 'cust_id': 10}
{'transact_id': 'a520859f-7cde-4294-bf79-ec2ef0c2467f', 'category': 'white', 'barcode': '6996277154185', 'item_desc': 'Entire worry hospital feel may.', 'amount': 92.69, 'transaction_date': '2023-01-03 13:45:03', 'cust_id': 10}
{'transact_id': '3922d6a1-d112-411e-9e78-bb4671e84fff', 'category': 'purple', 'barcode': '7318960584434', 'item_desc': 'Finally kind country thank.', 'amount': 21.89, 'transaction_date': '2022-12-29 09:00:26', 'cust_id': 11}
{'transact_id': 'fe40fd4c-6111-49b8-83c3-843211b1f10e', 'category': 'olive', 'barcode': '4676656262244', 'item_desc': 'Strong likely specific program artist information.', 'amount': 24.97, 'transaction_date': '2023-01-19 03:47:12', 'cust_id': 11}
{'transact_id': '331def13-f644-4099-8ac0-2fcc704e800f', 'category': 'aqua', 'barcode': '2299973443220', 'item_desc': 'Store blue conference those.', 'amount': 68.98, 'transaction_date': '2023-01-13 10:07:46', 'cust_id': 14}
{'transact_id': '57cdb9b6-d370-4aa2-8fbc-d2d8f1a15915', 'category': 'silver', 'barcode': '1115162814798', 'item_desc': 'Court dog method interesting cup.', 'amount': 66.5, 'transaction_date': '2022-12-29 06:04:30', 'cust_id': 14}
{'transact_id': '9124d0ef-9374-441e-9b33-31eb31a90ced', 'category': 'gray', 'barcode': '5617858920203', 'item_desc': 'Black director after person ahead red.', 'amount': 26.96, 'transaction_date': '2023-01-11 19:20:39', 'cust_id': 14}
{'transact_id': 'd418abe1-63dc-4cae-b152-f3cc92d0ad4a', 'category': 'yellow', 'barcode': '1829792571456', 'item_desc': 'Lead today best power see message.', 'amount': 11.24, 'transaction_date': '2022-12-31 03:16:32', 'cust_id': 14}
{'transact_id': '422a413a-590b-4f72-8aeb-a51c80318132', 'category': 'aqua', 'barcode': '9406622469286', 'item_desc': 'Power itself job see.', 'amount': 6.82, 'transaction_date': '2023-01-09 19:09:29', 'cust_id': 15}
{'transact_id': 'bc4125fc-08cb-4abe-8b13-b3b1903ae9c6', 'category': 'black', 'barcode': '7753423715275', 'item_desc': 'Material risk first.', 'amount': 89.39, 'transaction_date': '2023-01-23 03:24:02', 'cust_id': 15}
{'transact_id': 'ff4e4369-bcef-438b-87e2-457c9d684c98', 'category': 'black', 'barcode': '2242895060556', 'item_desc': 'Foreign strong walk admit specific firm.', 'amount': 63.49, 'transaction_date': '2022-12-29 22:12:09', 'cust_id': 15}
{'transact_id': 'd00a9e7a-0cea-428f-9145-a143fef36f99', 'category': 'black', 'barcode': '3010754625845', 'item_desc': 'Own book move for.', 'amount': 49.7, 'transaction_date': '2023-01-12 21:42:32', 'cust_id': 15}
{'transact_id': '33afa171-a652-4291-984d-6f52434bedf9', 'category': 'green', 'barcode': '7885711282777', 'item_desc': 'Without beat then crime decide.', 'amount': 10.45, 'transaction_date': '2023-01-05 04:33:24', 'cust_id': 15}
{'transact_id': 'cfba6338-f816-4b73-a972-19a7f847f45e', 'category': 'aqua', 'barcode': '8802078025372', 'item_desc': 'Site win movie.', 'amount': 34.12, 'transaction_date': '2023-01-07 12:22:34', 'cust_id': 16}
{'transact_id': '5223b620-5eef-4fac-ac95-3514ba3ecf6f', 'category': 'olive', 'barcode': '9389514040254', 'item_desc': 'Agree enjoy four south wall.', 'amount': 96.14, 'transaction_date': '2022-12-28 17:06:04', 'cust_id': 16}
{'transact_id': '33725df2-e14b-45a1-ac5d-50826e9a55c9', 'category': 'blue', 'barcode': '6079280166809', 'item_desc': 'Concern his debate follow guess generation.', 'amount': 3.38, 'transaction_date': '2023-01-17 20:53:25', 'cust_id': 16}
{'transact_id': '6a707466-7b43-4af1-8d31-a271a6b844c6', 'category': 'yellow', 'barcode': '5723406697760', 'item_desc': 'Republican sure risk read.', 'amount': 2.67, 'transaction_date': '2023-01-02 15:40:17', 'cust_id': 16}
{'transact_id': '5a31670b-9b68-43f2-a521-9c78b62ab791', 'category': 'black', 'barcode': '0555188918000', 'item_desc': 'Sense recently than floor help.', 'amount': 68.85, 'transaction_date': '2023-01-12 03:21:06', 'cust_id': 16}
{'transact_id': '499e66d2-9d14-4f01-b406-3ece92533be8', 'category': 'silver', 'barcode': '0298273765225', 'item_desc': 'Body chance or bed eye.', 'amount': 54.62, 'transaction_date': '2023-01-08 20:50:39', 'cust_id': 17}
{'transact_id': '02944716-af02-41a5-9c0c-fe120800e046', 'category': 'olive', 'barcode': '6233146681961', 'item_desc': 'Represent sell speech money night analysis.', 'amount': 17.21, 'transaction_date': '2023-01-18 11:17:00', 'cust_id': 17}
{'transact_id': 'f2946f03-67ee-433e-84e1-4108a2db49f6', 'category': 'lime', 'barcode': '4853164762385', 'item_desc': 'Beyond say respond.', 'amount': 5.18, 'transaction_date': '2022-12-29 06:06:12', 'cust_id': 17}
{'transact_id': '2d6cb57d-8636-438b-aad2-afe9e90df51e', 'category': 'navy', 'barcode': '4194943690230', 'item_desc': 'Heart director physical finish authority.', 'amount': 95.69, 'transaction_date': '2023-01-24 22:24:36', 'cust_id': 18}
{'transact_id': 'a947ea34-65d0-4f63-aa07-a8007b577102', 'category': 'purple', 'barcode': '1881524702910', 'item_desc': 'Impact suddenly character impact father order.', 'amount': 39.99, 'transaction_date': '2022-12-30 22:23:08', 'cust_id': 18}
{'transact_id': '02528b68-b537-4d04-9077-18712704abfc', 'category': 'yellow', 'barcode': '3905500585729', 'item_desc': 'Rock a be.', 'amount': 12.59, 'transaction_date': '2023-01-26 00:06:45', 'cust_id': 18}
{'transact_id': '389c4c6c-ac54-424e-8dd3-e4a22360efa0', 'category': 'teal', 'barcode': '4466529660662', 'item_desc': 'Take group cost defense send trouble.', 'amount': 71.48, 'transaction_date': '2023-01-21 21:44:42', 'cust_id': 18}
{'transact_id': '1568a178-9913-47cc-8d29-a42b67e10735', 'category': 'white', 'barcode': '8559913297868', 'item_desc': 'Politics such help.', 'amount': 14.57, 'transaction_date': '2023-01-25 19:03:23', 'cust_id': 18}
{'transact_id': '6430cfc8-ee6f-4edb-8616-d63cfe09d18b', 'category': 'silver', 'barcode': '1411496208099', 'item_desc': 'Serve certain focus bring sometimes trade.', 'amount': 19.13, 'transaction_date': '2023-01-01 00:35:52', 'cust_id': 19}
{'transact_id': '43f4d221-559d-43b1-bb65-228e26194408', 'category': 'maroon', 'barcode': '6697633324593', 'item_desc': 'Already level finally.', 'amount': 96.54, 'transaction_date': '2022-12-30 13:36:56', 'cust_id': 20}
{'transact_id': '24b696f8-eab8-4496-9634-5a396717ae22', 'category': 'olive', 'barcode': '6901266689999', 'item_desc': 'Level billion suffer.', 'amount': 33.54, 'transaction_date': '2023-01-01 08:04:41', 'cust_id': 21}
{'transact_id': '321e81c2-a0af-4092-b71e-0f00f2a20018', 'category': 'fuchsia', 'barcode': '4062429681198', 'item_desc': 'Serious hospital hit yeah.', 'amount': 73.42, 'transaction_date': '2023-01-07 01:20:14', 'cust_id': 21}
{'transact_id': '335ee894-b420-4b9b-923b-d4dd271f0578', 'category': 'gray', 'barcode': '2459484608482', 'item_desc': 'Although air themselves popular.', 'amount': 82.64, 'transaction_date': '2023-01-21 16:56:27', 'cust_id': 21}
{'transact_id': 'fb94a691-52a8-4680-8699-bba0487e1c19', 'category': 'white', 'barcode': '6474962867775', 'item_desc': 'Billion plant able PM.', 'amount': 37.91, 'transaction_date': '2023-01-24 19:56:44', 'cust_id': 21}
{'transact_id': '1b4e61c3-9f24-48e7-a7d8-4c02ec289a2d', 'category': 'olive', 'barcode': '1811234564652', 'item_desc': 'Either woman democratic Mr maintain treat.', 'amount': 38.77, 'transaction_date': '2022-12-31 15:48:25', 'cust_id': 23}
{'transact_id': '372c9bf1-64d8-4821-b9bb-9bae14374eb9', 'category': 'purple', 'barcode': '1797658169270', 'item_desc': 'National actually eight present.', 'amount': 25.6, 'transaction_date': '2023-01-20 10:49:38', 'cust_id': 23}
{'transact_id': 'e4981336-e09c-436b-a54c-5d2a9a88d7e0', 'category': 'teal', 'barcode': '7134112068801', 'item_desc': 'While assume executive customer.', 'amount': 56.41, 'transaction_date': '2023-01-17 10:13:19', 'cust_id': 23}
EOF
#########################################################################################
# add to items to path for future use
#########################################################################################
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_HOME=/opt/spark

echo "" >> ~/.profile
echo "#  set path variables here:" >> ~/.profile
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/.profile
echo "export SPARK_HOME=/opt/spark" >> ~/.profile

echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin:$JAVA_HOME/bin:$HOME/minio-binaries" >> ~/.profile

#########################################################################################
# source this to set the new variables in current running session
#########################################################################################
bash -l

