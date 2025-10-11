# Elasticsearch

## Admin management

## Nodes info

```
curl -k -v -X GET "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/_nodes" | jq
```

### Who's the master

```
_cat/master?v=true
```


### Status

```
curl -k -v -XGET "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/_cluster/health?filter_path=status,*_shards"| jq
```


### List shards

```
curl -v -k -X GET "https://elastic:asd34r123901@prodes1:9200/_cat/shards?h=index,shard,prirep,state,unassigned.reason"
```

Example output:

```
.reporting-2021-09-26                                         0 r STARTED
.reporting-2021-09-26                                         0 p STARTED
.kibana-event-log-7.13.0-000040                               0 r STARTED
.kibana-event-log-7.13.0-000040                               0 p STARTED
.apm-custom-link                                              0 r STARTED
.apm-custom-link                                              0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.03.03-000030 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.03.03-000030 0 r UNASSIGNED   NODE_LEFT
logstash-ls1-2024.06                                          0 r STARTED
logstash-ls1-2024.06                                          0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.11.25-000049 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.11.25-000049 0 r UNASSIGNED   NODE_LEFT
.ds-.logs-deprecation.elasticsearch-default-2022.10.14-000020 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2022.10.14-000020 0 r UNASSIGNED   NODE_LEFT
.ds-.logs-deprecation.elasticsearch-default-2023.10.13-000046 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.10.13-000046 0 r STARTED
.ds-.logs-deprecation.elasticsearch-default-2024.02.03-000054 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2024.02.03-000054 0 r UNASSIGNED   NODE_LEFT
.ds-.logs-deprecation.elasticsearch-default-2023.04.28-000034 0 p STARTED
.ds-.logs-deprecation.elasticsearch-default-2023.04.28-000034 0 r STARTED
.ds-.logs-deprecation.elasticsearch-default-2024.04.13-000059 0 r STARTED
```



### Allocation overview

```
curl -v -k -X GET "https://elastic:asd34r123901@prodes1:9200/_cat/allocation?v&s=disk.avail&h=node,disk.percent,disk.avail,disk.total,disk.used,disk.indices,shards"
```

Example output:
```
node    disk.percent disk.avail disk.total disk.used disk.indices shards
prodes2           93        6gb     96.7gb    90.6gb           0b      0
prodes3           93      6.7gb     96.7gb      90gb         85gb      9
prodes1           30     67.2gb     96.7gb    29.4gb       23.3gb     72
prodes4           17     79.6gb     96.7gb      17gb       12.7gb     78
prodes6           55     86.3gb    192.6gb   106.3gb      103.6gb     76
prodes5            9    174.2gb    192.6gb    18.4gb       15.4gb     64
prodes7            8    440.4gb    483.2gb    42.8gb       40.2gb     57
```


### List indices

```
curl -v -k -X GET "https://elastic:asd34r123901@prodes1:9200/_cat/indices?v&s=rep:desc,pri.store.size:desc&h=health,index,pri,rep,store.s
ize,pri.store.size"
```

Example output:
```
health index                                     pri rep store.size pri.store.size
green  logstash-2021.05.30-000001                  1   1      170gb           85gb
green  logstash-ls1-2024.07                        1   1      6.2gb          3.1gb
green  logstash-ls1-2024.03                        1   1      6.2gb          3.1gb
green  logstash-ls1-2024.04                        1   1      6.2gb          3.1gb
green  logstash-ls1-2024.05                        1   1      5.9gb          2.9gb
green  logstash-ls1-2024.09                        1   1      5.9gb          2.9gb
green  logstash-ls1-2024.06                        1   1      5.7gb          2.8gb
green  logstash-ls1-2024.01                        1   1      5.7gb          2.8gb
green  logstash-ls1-2024.08                        1   1      5.6gb          2.8gb
green  logstash-ls1-2024.02                        1   1      5.5gb          2.7gb
green  logstash-ls1-2023.12                        1   1      5.5gb          2.7gb
```

#### Better columns / better overview

```
./elasticapi "_cat/indices?bytes=mb&s=store.size:desc,index:asc&v=true"
```

## Settings

## Settings of a index

Please note the parameters in GET query. Modify them when needed.

```
curl -v -k -X GET "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/logstash-2021.05.30-000001/_settings?flat_settings=true&include_defaults=true" | jq
```



### Cluster settings query example

Please note the parameters in GET query. Modify them when needed.

```
curl -v -k -X GET "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/_cluster/settings?include_defaults&filter_path=*.cluster.routing.allocation.disk.watermark.high*"
  | jq
```

### Update settings

```
curl -H 'Content-Type: application/json' -v -k -X PUT "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/logstash-2021.05.30-000001/_settings" -d '{ "index": {
"blocks.read_only" : true } }'
```

## Operations

### Split a shard

```
curl -H 'Content-Type: application/json' -v -k -X POST "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/logstash-2021.05.30-000001/_split/split-logstash-2021.storfaen-001" -d '{"settings":{"index.number_of_shards": 2}}'
```

### Move index between nodes

```
curl -v -k -X POST "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/_cluster/reroute?metric=none" -d '{"commands":[{"move"{"index":"logstash-2021.05.30-000001", "sh
ard": 0, "from_node": "prodes3", "to_node": "prodes7"}}]}'
```

#### Watch over processes

```
_cat/recovery?v&h=i,s,t,ty,st,shost,thost,f,fp,b,bp
```

```
_cat/recovery?v=true&active_only=true&format=json
```




### Explain issues

```
curl -k -v -XGET "https://elastic:6tttVK0gPVoFegZIF77T@prodes1:9200/_cluster/allocation/explain?filter_path=index,node_allocation_decisions.node_name,node_allocation_decisions.deciders.*" | jq
```

```
_cluster/allocation/explain?filter_path=index,node_allocation_decisions.node_name,node_allocation_decisions.deciders.*
```

### Re-index task

#### Create

```
./elasticapi '_reindex?requests_per_second=-1&slices=auto&wait_for_completion=false' POST '{ "source": { "index": "logstash-2021.05.30-000001" }, "dest": { "index": "logstash-2021-new" } }'
```

#### Inspect task

```
./elasticapi '_tasks/JmWb-J3XS9CiZAf07idGHQ:1226743' | jq
```


#### Cancel

```
./elasticapi '_tasks/_cancel?nodes=JmWb-J3XS9CiZAf07idGHQ&actions=*reindex' POST '' | jq
```


## Helper scripts

### API Client

`elasticapi`: usage is for example: `./elasticapi "_cat/shards?v=true&h=index,shard,prirep,state,node,unassigned.reason&s=state"`

```bash
#!/usr/bin/env bash
set -x

method="GET"
if [[ $# -eq 0 ]] ; then
  api_function="_cluster/health?filter_path=status,*_shards"
else
  api_function="$1"
  if [[ $# -eq 3 ]] ; then
    method="${2:-GET}"
    data="$3"
  fi
fi

base_url="https://elastic:temmelighemmelig@prodes1:9200"

if [[ "$method" == "PUT" ]] || [[ "$method" == "POST" ]]; then
  curl -k -v -H'Content-Type: application/json' -d $data -X$method "${base_url}/${api_function}"
else
  curl -k -v -X$method "${base_url}/${api_function}"
fi
```


Example:

```
./elasticapi "_cat/recovery?v=true&index=logstash-2021.05.30-000001"
```
