#!/bin/bash

##########################################################################################
#  install some OS utilities 
#########################################################################################
sudo apt-get install wget curl -y

##########################################################################################
#  install a specific version of postgresql (version 14)
##########################################################################################
apt policy postgresql

##########################################################################################
#  install the pgp key for this version of postgresql:
##########################################################################################
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt update

sudo apt install postgresql-14 -y

sudo systemctl enable postgresql

##########################################################################################
#  backup the original postgresql conf file
##########################################################################################
sudo cp /etc/postgresql/14/main/postgresql.conf /etc/postgresql/14/main/postgresql.conf.orig

##########################################################################################
#  setup the database to allow listeners from any host
##########################################################################################
sudo sed -e 's,#listen_addresses = \x27localhost\x27,listen_addresses = \x27*\x27,g' -i /etc/postgresql/14/main/postgresql.conf

##########################################################################################
#  increase number of connections allowed in the database
##########################################################################################
sudo sed -e 's,max_connections = 100,max_connections = 300,g' -i /etc/postgresql/14/main/postgresql.conf

##########################################################################################
#  create a new 'pg_hba.conf' file
##########################################################################################
sudo mv /etc/postgresql/14/main/pg_hba.conf /etc/postgresql/14/main/pg_hba.conf.orig

cat <<EOF > pg_hba.conf
  # TYPE  DATABASE        USER            ADDRESS                 METHOD
  local   all             all                                     peer
  host    datagen         datagen        0.0.0.0/0                md5
  host    icecatalog      icecatalog     0.0.0.0/0                md5
EOF

##########################################################################################
#   set owner and permissions of this conf file
##########################################################################################
sudo mv pg_hba.conf /etc/postgresql/14/main/pg_hba.conf
sudo chown postgres:postgres /etc/postgresql/14/main/pg_hba.conf
sudo chmod 600 /etc/postgresql/14/main/pg_hba.conf

##########################################################################################
#  restart postgresql
##########################################################################################
sudo systemctl restart postgresql

##########################################################################################
#  create a DDL file for database 'icecatalog' 
##########################################################################################

cat <<EOF > ~/create_ddl_icecatalog.sql
CREATE ROLE icecatalog LOGIN PASSWORD 'supersecret1';
CREATE DATABASE icecatalog OWNER icecatalog ENCODING 'UTF-8';
ALTER USER icecatalog WITH SUPERUSER;
ALTER USER icecatalog WITH CREATEDB;
CREATE SCHEMA icecatalog;
EOF

##########################################################################################
#  run the sql DDL file to create the objects in the database 
##########################################################################################
sudo -u postgres psql < ~/create_ddl_icecatalog.sql

##########################################################################################
#  let's install a postgresql client only that we can use to test access to postgresql server on the red panda host:
##########################################################################################
sudo apt install postgresql-client  -y

##########################################################################################
#  install java-11-jdk
##########################################################################################
sudo apt install openjdk-11-jdk -y

##########################################################################################
#  Install maven 
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
#  download the jdbc jar file for postgres:  
##########################################################################################
wget https://jdbc.postgresql.org/download/postgresql-42.5.1.jar

sudo cp postgresql-42.5.1.jar /opt/spark/jars/

##########################################################################################
# download some aws jars:
##########################################################################################
wget https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.19.19/bundle-2.19.19.jar

sudo cp bundle-2.19.19.jar /opt/spark/jars/

wget https://repo1.maven.org/maven2/software/amazon/awssdk/url-connection-client/2.19.19/url-connection-client-2.19.19.jar
cp url-connection-client-2.19.19.jar /opt/spark/jars/

##########################################################################################
#  download iceberg spark runtime 
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

##########################################################################################
# grant permission to this directory to minio-user
##########################################################################################

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
#  install the 'MinIO Client' on this server 
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
#  lets create a user for iceberg metadata & tables using the minio cli and the  alias we just set
##########################################################################################
mc admin user add local icebergadmin supersecret1!

##########################################################################################
#  need to add the 'readwrite' minio policy to this new user: (these are just like aws policies)
##########################################################################################
mc admin policy set local readwrite user=icebergadmin

##########################################################################################
#  create a new alias for this admin user:
##########################################################################################
mc alias set icebergadmin http://127.0.0.1:9000 icebergadmin supersecret1!

##########################################################################################
#  create new 'Access Keys' for this user and redirect output to a file for automation later
##########################################################################################
mc admin user svcacct add icebergadmin icebergadmin >> ~/minio-output.properties

##########################################################################################
#  create a bucket as user icebergadmin for our iceberg data
##########################################################################################
mc mb icebergadmin/iceberg-data icebergadmin

##########################################################################################
#  let's reformat the output of access keys from an earlier step
##########################################################################################
sed -i "s/Access Key: /access_key=/g" ~/minio-output.properties
sed -i "s/Secret Key: /secret_key=/g" ~/minio-output.properties

##########################################################################################
#  let's  read the update file into memory to use these values to set aws configure
##########################################################################################
. ~/minio-output.properties

##########################################################################################
#  let's set up aws configure files from code (this is using the minio credentials) - The default region doesn't get used in minio
##########################################################################################
aws configure set aws_access_key_id $access_key
aws configure set aws_secret_access_key $secret_key
aws configure set default.region us-east-1

##########################################################################################
#  let's test that the aws cli can list our buckets in minio:
##########################################################################################
aws --endpoint-url http://127.0.0.1:9000 s3 ls

echo
##########################################################################################
#   create a directory for spark events, logs and some json files to be used in a lab
##########################################################################################
mkdir -p /opt/spark/logs
mkdir -p /opt/spark/spark-events
mkdir -p /opt/spark/input

##########################################################################################
#  Create a json records file of sample customer data to be used in a lab
##########################################################################################

cat <<EOF > /opt/spark/input/customers.json
{"last_name": "Thompson", "first_name": "Brenda", "street_address": "321 Nicole Ports Suite 204", "city": "South Lisachester", "state": "AS", "zip_code": "89409", "email": "wmoran@example.net", "home_phone": "486.884.6221x4431", "mobile": "(290)274-1564", "ssn": "483-79-5404", "job_title": "Housing manager/officer", "create_date": "2022-12-25 01:10:43", "cust_id": 10}
{"last_name": "Anderson", "first_name": "Jennifer", "street_address": "1392 Cervantes Isle", "city": "Adrianaton", "state": "IN", "zip_code": "15867", "email": "michaeltodd@example.com", "home_phone": "939-630-6773", "mobile": "904.337.2023x17453", "ssn": "583-07-6994", "job_title": "Clinical embryologist", "create_date": "2022-12-03 04:50:07", "cust_id": 11}
{"last_name": "Jefferson", "first_name": "William", "street_address": "543 Matthew Courts", "city": "South Nicholaston", "state": "WA", "zip_code": "17687", "email": "peterhouse@example.net", "home_phone": "+1-599-587-9051x2899", "mobile": "(915)689-1450", "ssn": "792-52-6700", "job_title": "Land", "create_date": "2022-11-28 08:17:10", "cust_id": 12}
{"last_name": "Romero", "first_name": "Jack", "street_address": "5929 Karen Ridges", "city": "Lake Richardburgh", "state": "OR", "zip_code": "78947", "email": "michellemitchell@example.net", "home_phone": "(402)664-1399x71255", "mobile": "450.580.6817x043", "ssn": "216-24-7271", "job_title": "Engineer, building services", "create_date": "2022-12-11 19:09:30", "cust_id": 13}
{"last_name": "Johnson", "first_name": "Robert", "street_address": "4313 Adams Islands", "city": "Tammybury", "state": "UT", "zip_code": "07361", "email": "morrischristopher@example.com", "home_phone": "(477)888-9999", "mobile": "220-403-9274x9709", "ssn": "012-26-8650", "job_title": "Rural practice surveyor", "create_date": "2022-12-08 05:28:56", "cust_id": 14}
EOF

##########################################################################################
#  Create another json records file to test out a  Merge Query in a lab
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
{"transact_id": "e786c399-ee9a-4053-a716-671bd456d06c", "category": "green", "barcode": "9688687184711", "item_desc": "Though evidence push.", "amount": 61.47, "transaction_date": "2022-12-31 03:52:13", "cust_id": 11}
{"transact_id": "58ccab06-38fe-45ab-a105-994f8bc51e1f", "category": "maroon", "barcode": "6270293172737", "item_desc": "Hotel toward radio exactly.", "amount": 18.26, "transaction_date": "2023-01-26 23:42:58", "cust_id": 11}
{"transact_id": "9f5a1c46-ac16-46c9-87fd-ff3ec4f36377", "category": "maroon", "barcode": "0000885336836", "item_desc": "West truth dog staff professor just.", "amount": 9.64, "transaction_date": "2023-01-24 15:51:44", "cust_id": 11}
{"transact_id": "c37e87fd-8833-44e9-85e3-ba2cb5e32c5d", "category": "purple", "barcode": "3898859302683", "item_desc": "Half chance hard.", "amount": 20.5, "transaction_date": "2023-01-13 08:54:35", "cust_id": 11}
{"transact_id": "ae165ddf-e99d-473f-a8ec-75c3235e2ca9", "category": "black", "barcode": "8835416937716", "item_desc": "Song tough born station break long.", "amount": 52.7, "transaction_date": "2023-01-24 00:04:58", "cust_id": 11}
{"transact_id": "3ed16c03-607f-40a1-b446-c1b2c18b8a58", "category": "purple", "barcode": "2387695378019", "item_desc": "Cover likely dog.", "amount": 94.27, "transaction_date": "2022-12-31 11:15:18", "cust_id": 12}
{"transact_id": "830e2d42-594c-4531-9256-6c7e3036f132", "category": "olive", "barcode": "1655418639701", "item_desc": "Difference major fast hear answer character.", "amount": 54.44, "transaction_date": "2023-01-03 22:01:20", "cust_id": 13}
{"transact_id": "4c8db6cf-2a66-4a3a-8474-00d3db8aeb92", "category": "aqua", "barcode": "4088755032541", "item_desc": "On without probably of.", "amount": 94.67, "transaction_date": "2023-01-08 02:11:48", "cust_id": 13}
{"transact_id": "ae54bcf5-250d-4076-854b-40a13cd74b7c", "category": "yellow", "barcode": "3783631322815", "item_desc": "Somebody yourself maintain only together.", "amount": 6.37, "transaction_date": "2023-01-02 09:39:39", "cust_id": 13}
{"transact_id": "c3d3f77a-54ba-4503-bf7c-53db29a775e7", "category": "lime", "barcode": "9466888768004", "item_desc": "By fear hospital certainly.", "amount": 94.8, "transaction_date": "2023-01-05 06:37:27", "cust_id": 13}
{"transact_id": "b5caf452-a44c-442d-a4cf-d88e2c08f7b3", "category": "black", "barcode": "5032052452372", "item_desc": "Imagine occur environment according more.", "amount": 62.94, "transaction_date": "2023-01-27 09:59:41", "cust_id": 14}
{"transact_id": "731fd64e-74af-4364-999e-67e8cccfd6ee", "category": "gray", "barcode": "2687016061218", "item_desc": "Game cover trade discover me read.", "amount": 70.9, "transaction_date": "2022-12-30 02:23:15", "cust_id": 14}
{"transact_id": "40edcc76-0ca0-4b88-990a-7e9abe400cbb", "category": "teal", "barcode": "1212133800184", "item_desc": "Form budget listen.", "amount": 31.5, "transaction_date": "2023-01-04 13:29:38", "cust_id": 14}
{"transact_id": "a811b772-8149-4ba2-ace0-7b658cd45c20", "category": "teal", "barcode": "8751563802922", "item_desc": "Weight hot mean.", "amount": 51.46, "transaction_date": "2023-01-20 23:50:30", "cust_id": 16}
{"transact_id": "8cc2a57f-5007-42b1-a4a2-722cf609bb76", "category": "purple", "barcode": "6267199327651", "item_desc": "Recognize ten area general.", "amount": 2.41, "transaction_date": "2023-01-19 17:20:57", "cust_id": 16}
{"transact_id": "931d9ff0-c82d-49e9-bc8d-bad319b20d84", "category": "white", "barcode": "9009659885601", "item_desc": "Safe medical start receive.", "amount": 61.77, "transaction_date": "2023-01-26 20:34:36", "cust_id": 16}
{"transact_id": "b0457bb2-8b72-4a1a-a247-6ca9d2c06be9", "category": "yellow", "barcode": "6453786338029", "item_desc": "Force set think cost.", "amount": 45.59, "transaction_date": "2023-01-24 11:39:20", "cust_id": 17}
{"transact_id": "b189cb88-6a14-4741-9286-102c379052d4", "category": "purple", "barcode": "2036094483571", "item_desc": "Nation consumer film fact only to.", "amount": 55.86, "transaction_date": "2023-01-12 16:29:53", "cust_id": 17}
{"transact_id": "c2564bb3-4485-4f2a-82e0-aa7e53cfc622", "category": "silver", "barcode": "8282187103947", "item_desc": "Sign standard pass evidence.", "amount": 38.78, "transaction_date": "2023-01-02 00:25:31", "cust_id": 18}
{"transact_id": "884469c2-32ee-439c-9f8a-570b9d49b152", "category": "lime", "barcode": "8529678377198", "item_desc": "Member write create.", "amount": 82.95, "transaction_date": "2023-01-03 13:49:19", "cust_id": 18}
{"transact_id": "0a722403-a7dd-4c9c-b958-95191ae841c1", "category": "green", "barcode": "6500182661487", "item_desc": "Over usually who table compare area model.", "amount": 54.1, "transaction_date": "2023-01-18 18:43:36", "cust_id": 18}
{"transact_id": "2b23b8c7-28db-4204-902f-a6fd3dd1f475", "category": "navy", "barcode": "1378348043058", "item_desc": "Technology one ahead general.", "amount": 54.67, "transaction_date": "2022-12-30 00:24:16", "cust_id": 19}
{"transact_id": "aacce2c5-2472-4d66-a445-3bc126745e0b", "category": "navy", "barcode": "2056653042902", "item_desc": "Speech hot letter hot.", "amount": 5.9, "transaction_date": "2023-01-08 16:16:32", "cust_id": 21}
{"transact_id": "20d157be-8a47-435a-a61f-c8ab68b34c8d", "category": "blue", "barcode": "7125652103787", "item_desc": "Strong society officer bag.", "amount": 46.41, "transaction_date": "2023-01-04 20:29:32", "cust_id": 21}
{"transact_id": "098478b0-d0bc-4140-b621-abe9a03a768e", "category": "fuchsia", "barcode": "8780633730896", "item_desc": "Oil stock film source.", "amount": 78.61, "transaction_date": "2023-01-26 22:36:26", "cust_id": 21}
{"transact_id": "8dbe22d8-050a-48a3-8526-b5c11230589e", "category": "navy", "barcode": "6879593096691", "item_desc": "Form affect seem side job.", "amount": 69.92, "transaction_date": "2022-12-31 21:41:30", "cust_id": 21}
{"transact_id": "d27cde76-40df-4eda-9567-07aba2e2a0b8", "category": "gray", "barcode": "3376554112825", "item_desc": "Inside page bag.", "amount": 76.63, "transaction_date": "2023-01-10 20:53:23", "cust_id": 22}
{"transact_id": "a4b87dc7-f401-4f13-9cfd-4858b0d575c0", "category": "yellow", "barcode": "0922971679088", "item_desc": "Guy more national.", "amount": 2.55, "transaction_date": "2023-01-25 14:29:42", "cust_id": 22}
{"transact_id": "48ce0556-fc57-4748-bd79-a146cd32147b", "category": "aqua", "barcode": "8702162059583", "item_desc": "Sometimes president response want.", "amount": 16.91, "transaction_date": "2023-01-03 12:00:34", "cust_id": 22}
{"transact_id": "b2dd711c-4d23-4c99-b980-bd7afd1ef62a", "category": "purple", "barcode": "0983651241193", "item_desc": "Born under focus budget east free.", "amount": 53.43, "transaction_date": "2023-01-01 16:42:59", "cust_id": 22}
{"transact_id": "913475de-32bb-4d80-aed0-1d9631dd0677", "category": "silver", "barcode": "9827839337951", "item_desc": "Address operation hold.", "amount": 55.79, "transaction_date": "2023-01-04 19:19:01", "cust_id": 23}
{"transact_id": "885ccb18-3d19-48aa-9ad3-095a562fe0a7", "category": "navy", "barcode": "5176084629125", "item_desc": "Thus second hospital development ball.", "amount": 65.89, "transaction_date": "2023-01-27 15:26:02", "cust_id": 24}
{"transact_id": "62cb9752-6da5-404a-a0a3-08192731db90", "category": "blue", "barcode": "8670289379405", "item_desc": "Prevent great yes travel where real.", "amount": 51.36, "transaction_date": "2023-01-11 23:35:22", "cust_id": 24}
{"transact_id": "04f07ef8-8453-40af-9d3e-da6e9693919b", "category": "olive", "barcode": "2009850879093", "item_desc": "Weight spring baby be thought degree.", "amount": 27.82, "transaction_date": "2023-01-22 13:56:49", "cust_id": 24}
EOF

#########################################################################################
# add items to path for future use
#########################################################################################
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_HOME=/opt/spark

echo "" >> ~/.profile
echo "#  set path variables here:" >> ~/.profile
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/.profile
echo "export SPARK_HOME=/opt/spark" >> ~/.profile

echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin:$JAVA_HOME/bin:$HOME/minio-binaries" >> ~/.profile

#########################################################################################
# source this to set our new variables in current session
#########################################################################################
bash -l

