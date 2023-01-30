---
Title:  Apache Iceberg Exploration with S3A storage. 
Author:  Tim Lepple
Date:  1.26.2023
Comments:  This repo will evolve over time with new items.
Tags:  Apache Iceberg | Minio | Apache SparkSQL | Apache PySpark
---

# Apache Iceberg Introduction Workshop

---

## Objective:

 * To evaluate Apache Iceberg with data stored in an S3a compliant object store on a traditional linux server.

My goal in this exercise was to go a little deeper than your typical `How To` guide that uses docker to spin up an enviroment. If that is what you are interested in the [Apache Iceberg website](https://iceberg.apache.org/spark-quickstart/) has a great quickstart for that. It has been my experience that to truely understand how some technologies work you need to know how they are wired together.  I took the time to install all the components manually and then I built the setup script in this repo so others could try it out too.  Please take the time to review that script `setup_iceberg.sh`.  Hopefully it becomes a reference for you one day.

---
## But Why Apache Iceberg:

A couple of items really jumped out at me when I read the documentation for the first time and I immediately saw the significant benefit it could provide.  Namely it could reduce the overall expense of enterprises to store and process the data they produce.  We all know that saving money in an enterprise is a good thing.  Here are the two items that really hit home for me:

  ### Item 1:
  ---
  *  Iceberg is designed for huge tables and is used in production where a single table can contain tens of petabytes of data.  This data can be stored in modern day object stores similar to these:
      *   A Cloud provider like [Amazon S3](https://aws.amazon.com/s3/?nc2=h_ql_prod_st_s3) 
      *   An on-premise solution that you build and support yourself like [Minio](https://min.io/).  
      *   Or a vendor hardware appliance like the [Dell ECS Enterprise Object Storage](https://www.dell.com/en-us/dt/storage/ecs/index.htm)
        
Regardless of which object store store you choose to deploy on your overall expense to support this platform will be significant.

  ### Item 2:
  ---
  *  Multi-petabyte tables can be read from a single node, without needing a distributed SQL engine to sift through table metadata.  That means the tools used in the examples I give below could be used to query the data stored in object stores without needing to dedicate expensive compute servers.

In a series of upcoming workshops, I will build out and document some new technologies that can be integrated with legacy solutions deployed by most organizations today.  It will give you a roadmap into how you can gain insights (in near real-time) from data produced in your legacy systems with minimal impact on those servers.  We will use a Change Data Capture (CDC) approach to pull the data from log files produced by the database providers and deliver it to our Iceberg solution we are building today.

---
---

# Highlights:
This setup script will build a single node platform that will setup a local S3a compliant object store, install a local SQL database, install a single node Apache Iceberg processing engine and lay the ground work for support of our Apache Iceberg tables and catalog.   

####  Object Storage Notes:
  ---
  *  This type of object store could also be setup to run in your own data center if that is a requirement.   Otherwise you could build and deploy something very similar in AWS using their S3 service instead.   I chose this option to demonstrate you have a lot of options you might not have considered.  It will store all of our Apache Iceberg data and catalog database objects.  
  *  This particular service is running Minio and it has a rest API that supports direct integration with the AWS CLI tool.  The script also installed the AWS CLI tools and configures the properities of the AWS CLI to work directly with Minio.

#### Local Database Notes:
  ---
  *  The local SQL database is PostgreSQL an it will host metadata with pointers to the Apache Iceberg table data persisted in our object store and the metadata for our Apache Iceberg catalog.  It maintains very small footprint.

####  Apache Iceberg Processing Engine Notes:
  ---
  *  This particular workshop is using Apache Spark but we could have chosen any one of the currently supported platforms:  
     *  Spark
     *  Flink
     *  Trino
     *  Presto
     *  Dermio
     *  StarRocks
     *  Amazon Athena
     *  Amazon EMR
     *  Impala
     *  Doris
     

---
---

---

###  Pre-Requisites:

 * I built this on a new install of Ubuntu Server
 * Version: 20.04.5 LTS 
 * Instance Specs: (min 2 core w/ 4 GB ram & 20 GB of disk) -- add more RAM if you have it to spare.

---

###  Install Git tools and pull this repo.
*  ssh into your new Ubuntu 20.04 instance and run the below command:

---

```
sudo apt-get install git-all -y

cd ~
git clone https://github.com/tlepple/iceberg-intro-workshop.git
```

---


### Start the build:

---

####  This script will setup and confgure the following tools on this one host:
 - minio (local S3a Service) (RELEASE.2023-01-12T02-06-16Z )
 - minio cli  (version RELEASE.2023-01-11T03-14-16Z )
 - openjdk 11 (version: 11 )
 - aws cli (version 2.19.19)
 - postgresql (version: 14)
 - apache spark (version: 3.3_2.12)
 - apache iceberg (version 1.1.0)

---

```
#  run it:
. ~/iceberg-intro-workshop/setup_iceberg.sh
```
 * Refill your coffee, this will run for about 5 min.

---
---

### The environment is now setup and we can run through some excercises:

---
---

###  AWS CLI Integration:

Let's test out the AWS CLI and run a command to list the buckets currently stored in our Minio object store.

---

##### Command:

```
aws --endpoint-url http://127.0.0.1:9000 s3 ls
```

#### Expected Output: The bucket name.
```
2023-01-24 22:58:38 iceberg-data
```
---

### Let's Explore Minio GUI from a browser.

Let's login into the minio GUI: navigate to `http:\\<host ip address>:9000` in a browser

  - Username: `icebergadmin`
  - Password: `supersecret1!`

---

![](./images/minio_login_screen.png)

---

`Object Browser` view with one bucket that was created during the install.  Bucket Name:  `iceberg-data`

---

![](./images/first_login.png)

---

Click on the tab `Access Keys` :  The key was created during the build too.

---

![](./images/access_keys_view.png)

---

Click on the tab: `Buckets` 

---

![](./images/initial_bucket_view.png)

---

### Start a standalone Spark Master Server 

```
cd $SPARK_HOME

. ./sbin/start-master.sh
```

---
##  Processing Engine Setup:

---
In this section we are configuring our processing engine (Apache Spark) that will use some of its tools to build our Apache Iceberg catalog and let us interact with data we will load.

---

##### Start a Spark Worker Server 

```
. ./sbin/start-worker.sh spark://$(hostname -f):7077
```
---

####  Check that the Spark GUI is up:
 * navigate to `http:\\<host ip address>:8080` in a browser

---

#### Sample view of Spark Master.

---

![](./images/spark_master_view.png)

---

####  Congigure the Spark-SQL service:
In this step we will initialize some variables that will be used when we start the Spark-SQL service

```
. ~/minio-output.properties

export AWS_ACCESS_KEY_ID=$access_key
export AWS_SECRET_ACCESS_KEY=$secret_key
export AWS_S3_ENDPOINT=127.0.0.1:9000
export AWS_REGION=us-east-1
export MINIO_REGION=us-east-1
export DEPENDENCIES="org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.1.0"
export AWS_SDK_VERSION=2.19.19
export AWS_MAVEN_GROUP=software.amazon.awssdk
export AWS_PACKAGES=(
"bundle"
"url-connection-client"
)
for pkg in "${AWS_PACKAGES[@]}"; do
export DEPENDENCIES+=",$AWS_MAVEN_GROUP:$pkg:$AWS_SDK_VERSION"
done
```

###  Start the Spark-SQL client service:

```
cd $SPARK_HOME

spark-sql --packages $DEPENDENCIES \
--conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
--conf spark.sql.cli.print.header=true \
--conf spark.sql.catalog.icecatalog=org.apache.iceberg.spark.SparkCatalog \
--conf spark.sql.catalog.icecatalog.catalog-impl=org.apache.iceberg.jdbc.JdbcCatalog \
--conf spark.sql.catalog.icecatalog.uri=jdbc:postgresql://127.0.0.1:5432/icecatalog \
--conf spark.sql.catalog.icecatalog.jdbc.user=icecatalog \
--conf spark.sql.catalog.icecatalog.jdbc.password=supersecret1 \
--conf spark.sql.catalog.icecatalog.warehouse=s3://iceberg-data \
--conf spark.sql.catalog.icecatalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO \
--conf spark.sql.catalog.icecatalog.s3.endpoint=http://127.0.0.1:9000 \
--conf spark.sql.catalog.sparkcatalog=org.apache.iceberg.spark.SparkSessionCatalog \
--conf spark.sql.defaultCatalog=icecatalog \
--conf spark.eventLog.enabled=true \
--conf spark.eventLog.dir=/opt/spark/spark-events \
--conf spark.history.fs.logDirectory=/opt/spark/spark-events \
--conf spark.sql.catalogImplementation=in-memory
```
---
####  Expected Output:
  *  the warnings can be ingored
```
23/01/25 19:48:19 WARN Utils: Your hostname, spark-ice2 resolves to a loopback address: 127.0.1.1; using 192.168.1.167 instead (on interface eth0)
23/01/25 19:48:19 WARN Utils: Set SPARK_LOCAL_IP if you need to bind to another address
:: loading settings :: url = jar:file:/opt/spark/jars/ivy-2.5.0.jar!/org/apache/ivy/core/settings/ivysettings.xml
Ivy Default Cache set to: /home/centos/.ivy2/cache
The jars for the packages stored in: /home/centos/.ivy2/jars
org.apache.iceberg#iceberg-spark-runtime-3.3_2.12 added as a dependency
software.amazon.awssdk#bundle added as a dependency
software.amazon.awssdk#url-connection-client added as a dependency
:: resolving dependencies :: org.apache.spark#spark-submit-parent-59d47579-1c2b-4e66-a92d-206be33d8afe;1.0
        confs: [default]
        found org.apache.iceberg#iceberg-spark-runtime-3.3_2.12;1.1.0 in central
        found software.amazon.awssdk#bundle;2.19.19 in central
        found software.amazon.eventstream#eventstream;1.0.1 in central
        found software.amazon.awssdk#url-connection-client;2.19.19 in central
        found software.amazon.awssdk#utils;2.19.19 in central
        found org.reactivestreams#reactive-streams;1.0.3 in central
        found software.amazon.awssdk#annotations;2.19.19 in central
        found org.slf4j#slf4j-api;1.7.30 in central
        found software.amazon.awssdk#http-client-spi;2.19.19 in central
        found software.amazon.awssdk#metrics-spi;2.19.19 in central
:: resolution report :: resolve 423ms :: artifacts dl 19ms
        :: modules in use:
        org.apache.iceberg#iceberg-spark-runtime-3.3_2.12;1.1.0 from central in [default]
        org.reactivestreams#reactive-streams;1.0.3 from central in [default]
        org.slf4j#slf4j-api;1.7.30 from central in [default]
        software.amazon.awssdk#annotations;2.19.19 from central in [default]
        software.amazon.awssdk#bundle;2.19.19 from central in [default]
        software.amazon.awssdk#http-client-spi;2.19.19 from central in [default]
        software.amazon.awssdk#metrics-spi;2.19.19 from central in [default]
        software.amazon.awssdk#url-connection-client;2.19.19 from central in [default]
        software.amazon.awssdk#utils;2.19.19 from central in [default]
        software.amazon.eventstream#eventstream;1.0.1 from central in [default]
        ---------------------------------------------------------------------
        |                  |            modules            ||   artifacts   |
        |       conf       | number| search|dwnlded|evicted|| number|dwnlded|
        ---------------------------------------------------------------------
        |      default     |   10  |   0   |   0   |   0   ||   10  |   0   |
        ---------------------------------------------------------------------
:: retrieving :: org.apache.spark#spark-submit-parent-59d47579-1c2b-4e66-a92d-206be33d8afe
        confs: [default]
        0 artifacts copied, 10 already retrieved (0kB/10ms)
23/01/25 19:48:20 WARN NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
Setting default log level to "WARN".
To adjust logging level use sc.setLogLevel(newLevel). For SparkR, use setLogLevel(newLevel).
23/01/25 19:48:28 WARN HiveConf: HiveConf of name hive.stats.jdbc.timeout does not exist
23/01/25 19:48:28 WARN HiveConf: HiveConf of name hive.stats.retries.wait does not exist
23/01/25 19:48:31 WARN ObjectStore: Version information not found in metastore. hive.metastore.schema.verification is not enabled so recording the schema version 2.3.0
23/01/25 19:48:31 WARN ObjectStore: setMetaStoreSchemaVersion called but recording version is disabled: version = 2.3.0, comment = Set by MetaStore centos@127.0.1.1
Spark master: local[*], Application Id: local-1674676103468
spark-sql>

```
---

####  Cursory Check:
From our new sqparksql terminall session run the following command:

```
SHOW CURRENT NAMESPACE;
```

#### Expected Output:

```
icecatalog
Time taken: 2.692 seconds, Fetched 1 row(s)
```
---

###  Exercises:
In this lab we will create our first iceberg table with `Spark-SQL`

#### Start the `SparkSQL` cli tool
 * from the sparksql console run the below commands

---

### Create Tables:
  * These will be run in the spark-sql cli
```
CREATE TABLE icecatalog.icecatalog.customer (
    first_name STRING,
    last_name STRING,
    street_address STRING,
    city STRING,
    state STRING,
    zip_code STRING,
    home_phone STRING,
    mobile STRING,
    email STRING,
    ssn STRING,
    job_title STRING,
    create_date STRING,
    cust_id BIGINT)
USING iceberg
OPTIONS (
    'write.object-storage.enabled'=true,
    'write.data.path'='s3://iceberg-data')
PARTITIONED BY (state);

CREATE TABLE icecatalog.icecatalog.transactions (
    transact_id STRING,
    transaction_date STRING,
    item_desc STRING,
    barcode STRING,
    category STRING,
    amount STRING,
    cust_id BIGINT)
USING iceberg
OPTIONS (
    'write.object-storage.enabled'=true,
    'write.data.path'='s3://iceberg-data');
```

---

###  Go examine the bucket in Minio from the GUI
  * It wrote out all the metadata and files into our object storage from the Apache Iceberg Catalog we created.

---
![](./images/bucket_first_table_metadata_view.png)
---

####  Insert some records:
  *  In this step we will load up some json records from a file created during setup.
  *  We will create a temporary view against this json file and then load the file with an INSERT statement.
---

##### Create temporary view statement:
```
CREATE TEMPORARY VIEW customerView
  USING org.apache.spark.sql.json
  OPTIONS (
    path "/opt/spark/input/customers.json"
  );
```

##### Load the existing icegberg table (created earlier) with:
```
INSERT INTO icecatalog.icecatalog.customer 
    SELECT 
             first_name, 
             last_name, 
             street_address, 
             city, 
             state, 
             zip_code, 
             home_phone,
             mobile,
             email,
             ssn,
             job_title,
             create_date,
             cust_id
    FROM customerView;

```
---

### Let's Add and Update some rows with an example `MERGE` Statement:

---
##### Create temporary view statement:
```
CREATE TEMPORARY VIEW mergeCustomerView
  USING org.apache.spark.sql.json
  OPTIONS (
    path "/opt/spark/input/update_customers.json"
  );
```

##### Merge records from a json file:  
```
MERGE INTO icecatalog.icecatalog.customer c
USING (SELECT
             first_name,
             last_name,
             street_address,
             city,
             state,
             zip_code,
             home_phone,
             mobile,
             email,
             ssn,
             job_title,
             create_date,
             cust_id
       FROM mergeCustomerView) j
ON c.cust_id = j.cust_id
WHEN MATCHED THEN UPDATE SET
             c.first_name = j.first_name,
             c.last_name = j.last_name,
             c.street_address = j.street_address,
             c.city = j.city,
             c.state = j.state,
             c.zip_code = j.zip_code,
             c.home_phone = j.home_phone,
             c.mobile = j.mobile,
             c.email = j.email,
             c.ssn = j.ssn,
             c.job_title = j.job_title,
             c.create_date = j.create_date
WHEN NOT MATCHED THEN INSERT *;
```

### Highlights of interest:
  *
  *
  
---

###  Let's take a look at Time Travel Queries from this table:
  *  In order to run a time travel query we need some metadata to pass into our query.

This query will return some metadata from our database.
  *  your results will be slightly different.

```
SELECT 
     committed_at, 
     snapshot_id, 
     parent_id 
  FROM icecatalog.icecatalog.customer.snapshots
  ORDER BY committed_at;
```
---

#### Output:

```
  committed_at    snapshot_id     parent_id
2023-01-26 16:58:31.873 2216914164877191507     NULL
2023-01-26 17:00:18.585 3276759594719593733     2216914164877191507
Time taken: 0.195 seconds, Fetched 2 row(s)
```

---

###  Query of the table after our first INSERT statement:
  *  replace thse snapshop id with your value:

In this step we will get results that show the data as it was originally loaded.
```
SELECT
    cust_id,
    first_name,
    last_name,
    create_date
  FROM icecatalog.icecatalog.customer
  VERSION AS OF 2216914164877191507
  ORDER by cust_id;

```

####  Output:

```

cust_id first_name      last_name       create_date
10      Brenda          Thompson        2022-12-25 01:10:43
11      Jennifer        Anderson        2022-12-03 04:50:07
12      William         Jefferson       2022-11-28 08:17:10
13      Jack            Romero          2022-12-11 19:09:30
14      Robert          Johnson         2022-12-08 05:28:56
Time taken: 0.349 seconds, Fetched 5 row(s)

```
---

### Query to get the results after the MERGE statement.
  *  replace thse snapshop id with your value:

In this step we will see results that have applied updates to existing rows and created some new rows.

```
SELECT
    cust_id,
    first_name,
    last_name,
    create_date
  FROM icecatalog.icecatalog.customer

 VERSION AS OF 3276759594719593733
 ORDER by cust_id;
```

#### Output:

```
cust_id first_name      last_name       create_date
10      Caitlyn         Rogers          2022-12-16 03:19:35
11      Brittany        Williams        2022-12-04 23:29:48
12      Victor          Gordon          2022-12-22 18:03:13
13      Shelby          Martinez        2022-11-27 16:10:42
14      Corey           Bridges         2022-12-11 23:29:52
15      Benjamin        Rocha           2022-12-10 07:39:35
16      Jonathan        Lawrence        2022-11-27 23:44:14
17      Thomas          Taylor          2022-12-07 12:33:45
18      Jeffrey         Williamson      2022-12-13 16:58:43
19      Joseph          Mccullough      2022-12-05 05:33:56
20      Evan            Kirby           2022-12-20 14:23:43
21      Teresa          Pittman         2022-12-26 05:14:24
22      Alicia          Byrd            2022-12-17 18:20:51
23      Kathleen        Ellis           2022-12-08 04:01:44
24      Tony            Lee             2022-12-24 17:10:32
Time taken: 0.432 seconds, Fetched 15 row(s)
```

---

### Exit out of `sparksql` cli.

```
exit;

```
---

### Let's try out `pyspark` and load our `Transactions` table with a pyspark dataFrame
  * pyspark isn't as feature rich as the sparksql client (in future versions it should catch up).  For example it doesn't support the `MERGE` example we tested earlier.

---

###  Start `pyspark` cli

```
cd $SPARK_HOME
pyspark
```

---

#### Expected Output:

---

```
Python 3.8.10 (default, Nov 14 2022, 12:59:47) 
[GCC 9.4.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
23/01/26 01:44:27 WARN Utils: Your hostname, spark-ice2 resolves to a loopback address: 127.0.1.1; using 192.168.1.167 instead (on interface eth0)
23/01/26 01:44:27 WARN Utils: Set SPARK_LOCAL_IP if you need to bind to another address
Setting default log level to "WARN".
To adjust logging level use sc.setLogLevel(newLevel). For SparkR, use setLogLevel(newLevel).
23/01/26 01:44:28 WARN NativeCodeLoader: Unable to load native-hadoop library for your platform... using builtin-java classes where applicable
Welcome to
      ____              __
     / __/__  ___ _____/ /__
    _\ \/ _ \/ _ `/ __/  '_/
   /__ / .__/\_,_/_/ /_/\_\   version 3.3.1
      /_/

Using Python version 3.8.10 (default, Nov 14 2022 12:59:47)
Spark context Web UI available at http://192.168.1.167:4040
Spark context available as 'sc' (master = local[*], app id = local-1674697469102).
SparkSession available as 'spark'.
>>> 

```

###  In this section we will load our `Transactions` data from a json file from Pyspark  

 * code blocks are commented:

---

```
# import SparkSession
from pyspark.sql import SparkSession

# create SparkSession
spark = SparkSession.builder \
     .appName("Python Spark SQL example") \
     .config("spark.jars.packages", "org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.1.0,software.amazon.awssdk:bundle:2.19.19,software.amazon.awssdk:url-connection-client:2.19.19") \
     .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
     .config("spark.sql.catalog.icecatalog", "org.apache.iceberg.spark.SparkCatalog") \
     .config("spark.sql.catalog.icecatalog.catalog-impl", "org.apache.iceberg.jdbc.JdbcCatalog") \
     .config("spark.sql.catalog.icecatalog.uri", "jdbc:postgresql://127.0.0.1:5432/icecatalog") \
     .config("spark.sql.catalog.icecatalog.jdbc.user", "icecatalog") \
     .config("spark.sql.catalog.icecatalog.jdbc.password", "supersecret1") \
     .config("spark.sql.catalog.icecatalog.warehouse", "s3://iceberg-data") \
     .config("spark.sql.catalog.icecatalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
     .config("spark.sql.catalog.icecatalog.s3.endpoint", "http://127.0.0.1:9000") \
     .config("spark.sql.catalog.sparkcatalog", "icecatalog") \
     .config("spark.eventLog.enabled", "true") \
     .config("spark.eventLog.dir", "/opt/spark/spark-events") \
     .config("spark.history.fs.logDirectory", "/opt/spark/spark-events") \
     .config("spark.sql.catalogImplementation", "in-memory") \
     .getOrCreate()

# A JSON dataset is pointed to by path
path = "/opt/spark/input/transactions.json"

#  read json into the DataFrame
transactionsDF = spark.read.json(path)

# visualize the inferred schema
transactionsDF.printSchema()

# print out the dataframe in this cli
transactionsDF.show()

# Append these transactions to the table we created in an earlier step `icecatalog.icecatalog.transactions`
transactionsDF.writeTo("icecatalog.icecatalog.transactions").append()

# stop the sparkSession
spark.stop()

# Exit out of the editor:
quit();

```
---

#### Expected Output:

---

```
>>> # import SparkSession
>>> from pyspark.sql import SparkSession
>>> 
>>> # create SparkSession
>>> spark = SparkSession.builder \
...      .appName("Python Spark SQL example") \
...      .config("spark.jars.packages", "org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.1.0,software.amazon.awssdk:bundle:2.19.19,software.amazon.awssdk:url-connection-client:2.19.19") \
...      .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
...      .config("spark.sql.catalog.icecatalog", "org.apache.iceberg.spark.SparkCatalog") \
...      .config("spark.sql.catalog.icecatalog.catalog-impl", "org.apache.iceberg.jdbc.JdbcCatalog") \
...      .config("spark.sql.catalog.icecatalog.uri", "jdbc:postgresql://127.0.0.1:5432/icecatalog") \
...      .config("spark.sql.catalog.icecatalog.jdbc.user", "icecatalog") \
...      .config("spark.sql.catalog.icecatalog.jdbc.password", "supersecret1") \
...      .config("spark.sql.catalog.icecatalog.warehouse", "s3://iceberg-data") \
...      .config("spark.sql.catalog.icecatalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO") \
...      .config("spark.sql.catalog.icecatalog.s3.endpoint", "http://127.0.0.1:9000") \
...      .config("spark.sql.catalog.sparkcatalog", "icecatalog") \
...      .config("spark.eventLog.enabled", "true") \
...      .config("spark.eventLog.dir", "/opt/spark/spark-events") \
...      .config("spark.history.fs.logDirectory", "/opt/spark/spark-events") \
...      .config("spark.sql.catalogImplementation", "in-memory") \
...      .getOrCreate()
23/01/26 02:04:13 WARN SparkSession: Using an existing Spark session; only runtime SQL configurations will take effect.
>>> 
>>> # A JSON dataset is pointed to by path
>>> path = "/opt/spark/input/transactions.json"
>>> 
>>> #  read json into the DataFrame
>>> transactionsDF = spark.read.json(path)
>>> 
>>> # visualize the inferred schema
>>> transactionsDF.printSchema()
root
 |-- amount: double (nullable = true)
 |-- barcode: string (nullable = true)
 |-- category: string (nullable = true)
 |-- cust_id: long (nullable = true)
 |-- item_desc: string (nullable = true)
 |-- transact_id: string (nullable = true)
 |-- transaction_date: string (nullable = true)

>>> 
>>> # print out the dataframe in this cli
>>> transactionsDF.show()
+------+-------------+--------+-------+--------------------+--------------------+-------------------+
|amount|      barcode|category|cust_id|           item_desc|         transact_id|   transaction_date|
+------+-------------+--------+-------+--------------------+--------------------+-------------------+
| 50.63|4541397840276|  purple|     10| Than explain cover.|586fef8b-00da-421...|2023-01-08 00:11:25|
| 95.37|2308832642138|   green|     10| Necessary body oil.|e8809684-7997-4cc...|2023-01-23 17:23:04|
|  9.71|1644304420912|    teal|     10|Recent property a...|18bb3472-56c0-48e...|2023-01-18 18:12:44|
| 92.69|6996277154185|   white|     10|Entire worry hosp...|a520859f-7cde-429...|2023-01-03 13:45:03|
| 21.89|7318960584434|  purple|     11|Finally kind coun...|3922d6a1-d112-411...|2022-12-29 09:00:26|
| 24.97|4676656262244|   olive|     11|Strong likely spe...|fe40fd4c-6111-49b...|2023-01-19 03:47:12|
| 68.98|2299973443220|    aqua|     14|Store blue confer...|331def13-f644-409...|2023-01-13 10:07:46|
|  66.5|1115162814798|  silver|     14|Court dog method ...|57cdb9b6-d370-4aa...|2022-12-29 06:04:30|
| 26.96|5617858920203|    gray|     14|Black director af...|9124d0ef-9374-441...|2023-01-11 19:20:39|
| 11.24|1829792571456|  yellow|     14|Lead today best p...|d418abe1-63dc-4ca...|2022-12-31 03:16:32|
|  6.82|9406622469286|    aqua|     15|Power itself job ...|422a413a-590b-4f7...|2023-01-09 19:09:29|
| 89.39|7753423715275|   black|     15|Material risk first.|bc4125fc-08cb-4ab...|2023-01-23 03:24:02|
| 63.49|2242895060556|   black|     15|Foreign strong wa...|ff4e4369-bcef-438...|2022-12-29 22:12:09|
|  49.7|3010754625845|   black|     15|  Own book move for.|d00a9e7a-0cea-428...|2023-01-12 21:42:32|
| 10.45|7885711282777|   green|     15|Without beat then...|33afa171-a652-429...|2023-01-05 04:33:24|
| 34.12|8802078025372|    aqua|     16|     Site win movie.|cfba6338-f816-4b7...|2023-01-07 12:22:34|
| 96.14|9389514040254|   olive|     16|Agree enjoy four ...|5223b620-5eef-4fa...|2022-12-28 17:06:04|
|  3.38|6079280166809|    blue|     16|Concern his debat...|33725df2-e14b-45a...|2023-01-17 20:53:25|
|  2.67|5723406697760|  yellow|     16|Republican sure r...|6a707466-7b43-4af...|2023-01-02 15:40:17|
| 68.85|0555188918000|   black|     16|Sense recently th...|5a31670b-9b68-43f...|2023-01-12 03:21:06|
+------+-------------+--------+-------+--------------------+--------------------+-------------------+
only showing top 20 rows

>>> transactionsDF.writeTo("icecatalog.icecatalog.transactions").append()
SLF4J: Failed to load class "org.slf4j.impl.StaticLoggerBinder".
SLF4J: Defaulting to no-operation (NOP) logger implementation
SLF4J: See http://www.slf4j.org/codes.html#StaticLoggerBinder for further details.
>>> spark.stop()                                                                
>>> quit();

```
