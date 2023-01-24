#!/bin/bash

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
#  download apach spark standalone
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
#
##########################################################################################



#########################################################################################
#   Everything above here works in a script... below needs tweaking to get to work with minio clients
##########################################################################################

##########################################################################################
#
##########################################################################################
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
#  let's set up aws configure files from code
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

