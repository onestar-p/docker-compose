## RabbitMQ 集群配置
- ```container_name: rabbitmq_01```和```hostname: rabbitmq_node_01```用于集群节点之间的区分
- 服务器```hosts```配置 ```rabbitmq_node_01```，用于节点之间的互通。例如：```192.168.1.108 rabbitmq_node_01```。
- 集群之间的```.erlang.cookie```必须保持一致，如果不一致可手动修改
- 加入集群：
> 以 rabbitmq_node_02 节点为例，以rabbitmq_node_01作为集群加入rabbitmq_node_01。
```
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl join_cluster rabbit@rabbitmq_node_01
rabbitmqctl start_app
```