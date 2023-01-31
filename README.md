# ceph-rgw-ms-jenkins
Jenkins frontend for generating high load and capacity rgw multi-site workloads

# MS Jenkins Operation:

## MS Test flow Overview:

### Main Jenkins Dashboard:

![image](https://user-images.githubusercontent.com/31659604/215765711-121ace9a-ad39-464d-8458-5340ff34bf3f.png)

#### Items Overview:
+ **10_Build_MS** : compiles a branch from github for each MS site
+ **20_Start_MS** : starts vstart on both MS sites
+ **30_HSBench_Execute_Stage** : run a specific hsbench 25M PUT objects MS sync stage
+ **35_HSBench_Execute_Multi-stage** : run 25M PUT stages continously until 400M objs of sync stage sync failure
+ **40_Sync-Status_MS** : monitos sync status and bucket sync status of both site
+ **50_Stop_MS** : stop both MS sites

To start a Job Project click on the Green Arrow to the right of it.

## MS Test flow Job Project description:

### 10_Build_MS
![image](https://user-images.githubusercontent.com/31659604/215874645-e46f7f62-f7be-419f-b220-28a2007e52fb.png)
This Project will clone the GITHUB_REMOTE to the SRC_DIR_MS(default val is OK) directory and switch to the GITHUB_BRANCH branch
then build a _vstart_ target with _CMAKE_BUILD_TYPE=RelWithDebInfo_ setting
for a specific MS_ZONE - Primary: `1` or Secondary: `2`
(DO NOT build both sites at the same time as it may cause anOOM because the build process is specifying `-j` to utilize all the machine cores)

### 20_Start_MS
![image](https://user-images.githubusercontent.com/31659604/215876799-b1a998e5-70ad-48e6-8698-06912a2a2e5a.png)
This Project will `vstart.sh` both MS sites build by the previous Project, overide/add any necesary ceph.conf params as necesary by modifying VSTART_CONF_PARAMS_MS, during the MS vstart _s3cmd_ is executed to create the pools, if necesary to change the keys specify appropritate S3CFG_PATH_MS (default val is OK), modify the DEBUG_* values as necesary (default vals are OK)

### 30_HSBench_Execute_Stage
![image](https://user-images.githubusercontent.com/31659604/215877912-724c8b28-db31-4705-afae-d92f9e8cc787.png)
This Project will run **one** bi-directional _hsbench_ load stage (each stage PUTs 12,500,000 M of 4KB objects to each site resulting in 25,000,000 after sync has completed)
The Project run will result is success or failure per succesfull sync completion (same number of objects on both sited and sync status + bucket sync status caught-up)

### 35_HSBench_Execute_Multi-stage
![image](https://user-images.githubusercontent.com/31659604/215880569-823991ea-2b96-44b9-ad8f-68d5ca92c692.png)
This Project will run a squence of the above sync stages, verifying that sucsessfull sync conditions between each of the stages
selecting for example HSBENCH_FROM_STAGE: `1` to HSBENCH_TO_STAGE: `16` will result in 400M object sync (the max possible because of disk space limitations)

### 40_Sync-Status_MS
![image](https://user-images.githubusercontent.com/31659604/215881715-56d7f163-60f5-4cd9-9edb-5d7007a2dddd.png)
This Project will run a _sync status_, _bucket sync status_ and _rados df_ on both zones, (this Project does not require any parameters)

### 50_Stop_MS
This Project will execcute `stop.sh` on both MS sites (WARNING: this Project does not require any parameters)


[//]: # (# MS Jenkins Installation:)

