# 二、基础集群部署 - kubernetes-simple
## 1. 部署ETCD（主节点）
#### 1.1 简介
&emsp;&emsp;kubernetes需要存储很多东西，像它本身的节点信息，组件信息，还有通过kubernetes运行的pod，deployment，service等等。都需要持久化。etcd就是它的数据中心。生产环境中为了保证数据中心的高可用和数据的一致性，一般会部署最少三个节点。我们这里以学习为主就只在主节点部署一个实例。
> 如果你的环境已经有了etcd服务(不管是单点还是集群)，可以忽略这一步。前提是你在生成配置的时候填写了自己的etcd endpoint哦~

#### 1.2 部署
**etcd的二进制文件和服务的配置我们都已经准备好，现在的目的就是把它做成系统服务并启动。**

```bash
#把服务配置文件copy到系统服务目录
$ cp ~/kubernetes-starter/target/master-node/etcd.service /lib/systemd/system/
#enable服务
$ systemctl enable etcd.service
#创建工作目录(保存数据的地方)
$ mkdir -p /var/lib/etcd
# 启动服务
$ service etcd start
# 查看服务日志，看是否有错误信息，确保服务正常
$ journalctl -f -u etcd.service
```

## 2. 部署APIServer（主节点）
#### 2.1 简介
kube-apiserver是Kubernetes最重要的核心组件之一，主要提供以下的功能
- 提供集群管理的REST API接口，包括认证授权（我们现在没有用到）数据校验以及集群状态变更等
- 提供其他模块之间的数据交互和通信的枢纽（其他模块通过API Server查询或修改数据，只有API Server才直接操作etcd）

> 生产环境为了保证apiserver的高可用一般会部署2+个节点，在上层做一个lb做负载均衡，比如haproxy。由于单节点和多节点在apiserver这一层说来没什么区别，所以我们学习部署一个节点就足够啦

#### 2.2 部署
APIServer的部署方式也是通过系统服务。部署流程跟etcd完全一样，不再注释
```bash
$ cp target/master-node/kube-apiserver.service /lib/systemd/system/
$ systemctl enable kube-apiserver.service
$ service kube-apiserver start
$ journalctl -f -u kube-apiserver
```

#### 2.3 重点配置说明
> [Unit]  
> Description=Kubernetes API Server  
> ...  
> [Service]  
> \#可执行文件的位置  
> ExecStart=/home/michael/bin/kube-apiserver \\  
> \#非安全端口(8080)绑定的监听地址 这里表示监听所有地址  
> --insecure-bind-address=0.0.0.0 \\  
> \#不使用https  
> --kubelet-https=false \\  
> \#kubernetes集群的虚拟ip的地址范围  
> --service-cluster-ip-range=10.68.0.0/16 \\  
> \#service的nodeport的端口范围限制  
>   --service-node-port-range=20000-40000 \\  
> \#很多地方都需要和etcd打交道，也是唯一可以直接操作etcd的模块  
>   --etcd-servers=http://192.168.1.102:2379 \\  
> ...  

## 3. 部署ControllerManager（主节点）
#### 3.1 简介
Controller Manager由kube-controller-manager和cloud-controller-manager组成，是Kubernetes的大脑，它通过apiserver监控整个集群的状态，并确保集群处于预期的工作状态。
kube-controller-manager由一系列的控制器组成，像Replication Controller控制副本，Node Controller节点控制，Deployment Controller管理deployment等等
cloud-controller-manager在Kubernetes启用Cloud Provider的时候才需要，用来配合云服务提供商的控制
> controller-manager、scheduler和apiserver 三者的功能紧密相关，一般运行在同一个机器上，我们可以把它们当做一个整体来看，所以保证了apiserver的高可用即是保证了三个模块的高可用。也可以同时启动多个controller-manager进程，但只有一个会被选举为leader提供服务。

#### 3.2 部署
**通过系统服务方式部署**
```bash
$ cp target/master-node/kube-controller-manager.service /lib/systemd/system/
$ systemctl enable kube-controller-manager.service
$ service kube-controller-manager start
$ journalctl -f -u kube-controller-manager
```
#### 3.3 重点配置说明
> [Unit]  
> Description=Kubernetes Controller Manager  
> ...  
> [Service]  
> ExecStart=/home/michael/bin/kube-controller-manager \\  
> \#对外服务的监听地址，这里表示只有本机的程序可以访问它  
>   --address=127.0.0.1 \\  
>   \#apiserver的url  
>   --master=http://127.0.0.1:8080 \\  
>   \#服务虚拟ip范围，同apiserver的配置  
>  --service-cluster-ip-range=10.68.0.0/16 \\  
>  \#pod的ip地址范围  
>  --cluster-cidr=172.20.0.0/16 \\  
>  \#下面两个表示不使用证书，用空值覆盖默认值  
>  --cluster-signing-cert-file= \\  
>  --cluster-signing-key-file= \\  
> ...  

## 4. 部署Scheduler（主节点）
#### 4.1 简介
kube-scheduler负责分配调度Pod到集群内的节点上，它监听kube-apiserver，查询还未分配Node的Pod，然后根据调度策略为这些Pod分配节点。我们前面讲到的kubernetes的各种调度策略就是它实现的。

#### 4.2 部署
**通过系统服务方式部署**
```bash
$ cp target/master-node/kube-scheduler.service /lib/systemd/system/
$ systemctl enable kube-scheduler.service
$ service kube-scheduler start
$ journalctl -f -u kube-scheduler
```

#### 4.3 重点配置说明
> [Unit]  
> Description=Kubernetes Scheduler  
> ...  
> [Service]  
> ExecStart=/home/michael/bin/kube-scheduler \\  
>  \#对外服务的监听地址，这里表示只有本机的程序可以访问它  
>   --address=127.0.0.1 \\  
>   \#apiserver的url  
>   --master=http://127.0.0.1:8080 \\  
> ...  

## 5. 部署CalicoNode（所有节点）
#### 5.1 简介
Calico实现了CNI接口，是kubernetes网络方案的一种选择，它一个纯三层的数据中心网络方案（不需要Overlay），并且与OpenStack、Kubernetes、AWS、GCE等IaaS和容器平台都有良好的集成。
Calico在每一个计算节点利用Linux Kernel实现了一个高效的vRouter来负责数据转发，而每个vRouter通过BGP协议负责把自己上运行的workload的路由信息像整个Calico网络内传播——小规模部署可以直接互联，大规模下可通过指定的BGP route reflector来完成。 这样保证最终所有的workload之间的数据流量都是通过IP路由的方式完成互联的。
#### 5.2 部署
**calico是通过系统服务+docker方式完成的**
```bash
$ cp target/all-node/kube-calico.service /lib/systemd/system/
$ systemctl enable kube-calico.service
$ service kube-calico start
$ journalctl -f -u kube-calico
```
#### 5.3 calico可用性验证
**查看容器运行情况**
```bash
$ docker ps
CONTAINER ID   IMAGE                COMMAND        CREATED ...
4d371b58928b   calico/node:v2.6.2   "start_runit"  3 hours ago...
```
**查看节点运行情况**
```bash
$ calicoctl node status
Calico process is running.
IPv4 BGP status
+---------------+-------------------+-------+----------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+---------------+-------------------+-------+----------+-------------+
| 192.168.1.103 | node-to-node mesh | up    | 13:13:13 | Established |
+---------------+-------------------+-------+----------+-------------+
IPv6 BGP status
No IPv6 peers found.
```
**查看端口BGP 协议是通过TCP 连接来建立邻居的，因此可以用netstat 命令验证 BGP Peer**
```bash
$ netstat -natp|grep ESTABLISHED|grep 179
tcp        0      0 192.168.1.102:60959     192.168.1.103:179       ESTABLISHED 29680/bird
```
**查看集群ippool情况**
```bash
$ calicoctl get ipPool -o yaml
- apiVersion: v1
  kind: ipPool
  metadata:
    cidr: 172.20.0.0/16
  spec:
    nat-outgoing: true
```
#### 5.4 重点配置说明
> [Unit]  
> Description=calico node  
> ...  
> [Service]  
> \#以docker方式运行  
> ExecStart=/usr/bin/docker run --net=host --privileged --name=calico-node \\  
> \#指定etcd endpoints（这里主要负责网络元数据一致性，确保Calico网络状态的准确性）  
>   -e ETCD_ENDPOINTS=http://192.168.1.102:2379 \\  
> \#网络地址范围（同上面ControllerManager）  
>   -e CALICO_IPV4POOL_CIDR=172.20.0.0/16 \\  
> \#镜像名，为了加快大家的下载速度，镜像都放到了阿里云上  
>   registry.cn-hangzhou.aliyuncs.com/imooc/calico-node:v2.6.2  

## 6. 配置kubectl命令（任意节点）
#### 6.1 简介
kubectl是Kubernetes的命令行工具，是Kubernetes用户和管理员必备的管理工具。
kubectl提供了大量的子命令，方便管理Kubernetes集群中的各种功能。
#### 6.2 初始化
使用kubectl的第一步是配置Kubernetes集群以及认证方式，包括：
- cluster信息：api-server地址
- 用户信息：用户名、密码或密钥
- Context：cluster、用户信息以及Namespace的组合

我们这没有安全相关的东西，只需要设置好api-server和上下文就好啦：
```bash
#指定apiserver地址（ip替换为你自己的api-server地址）
kubectl config set-cluster kubernetes  --server=http://192.168.1.102:8080
#指定设置上下文，指定cluster
kubectl config set-context kubernetes --cluster=kubernetes
#选择默认的上下文
kubectl config use-context kubernetes
```
> 通过上面的设置最终目的是生成了一个配置文件：~/.kube/config，当然你也可以手写或复制一个文件放在那，就不需要上面的命令了。

## 7. 配置kubelet（工作节点）
#### 7.1 简介
每个工作节点上都运行一个kubelet服务进程，默认监听10250端口，接收并执行master发来的指令，管理Pod及Pod中的容器。每个kubelet进程会在API Server上注册节点自身信息，定期向master节点汇报节点的资源使用情况，并通过cAdvisor监控节点和容器的资源。
#### 7.2 部署
**通过系统服务方式部署，但步骤会多一些，具体如下：**
```bash
#确保相关目录存在
$ mkdir -p /var/lib/kubelet
$ mkdir -p /etc/kubernetes
$ mkdir -p /etc/cni/net.d

#复制kubelet服务配置文件
$ cp target/worker-node/kubelet.service /lib/systemd/system/
#复制kubelet依赖的配置文件
$ cp target/worker-node/kubelet.kubeconfig /etc/kubernetes/
#复制kubelet用到的cni插件配置文件
$ cp target/worker-node/10-calico.conf /etc/cni/net.d/

$ systemctl enable kubelet.service
$ service kubelet start
$ journalctl -f -u kubelet
```
#### 7.3 重点配置说明
**kubelet.service**
> [Unit]  
Description=Kubernetes Kubelet  
[Service]  
\#kubelet工作目录，存储当前节点容器，pod等信息  
WorkingDirectory=/var/lib/kubelet  
ExecStart=/home/michael/bin/kubelet \\  
  \#对外服务的监听地址  
  --address=192.168.1.103 \\  
  \#指定基础容器的镜像，负责创建Pod 内部共享的网络、文件系统等，这个基础容器非常重要：K8S每一个运行的 POD里面必然包含这个基础容器，如果它没有运行起来那么你的POD 肯定创建不了  
  --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/imooc/pause-amd64:3.0 \\  
  \#访问集群方式的配置，如api-server地址等  
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\  
  \#声明cni网络插件  
  --network-plugin=cni \\  
  \#cni网络配置目录，kubelet会读取该目录下得网络配置  
  --cni-conf-dir=/etc/cni/net.d \\  
  \#指定 kubedns 的 Service IP(可以先分配，后续创建 kubedns 服务时指定该 IP)，--cluster-domain 指定域名后缀，这两个参数同时指定后才会生效  
 --cluster-dns=10.68.0.2 \\  
  ...  

**kubelet.kubeconfig**  
kubelet依赖的一个配置，格式看也是我们后面经常遇到的yaml格式，描述了kubelet访问apiserver的方式
> apiVersion: v1  
> clusters:  
> \- cluster:  
> \#跳过tls，即是kubernetes的认证  
>     insecure-skip-tls-verify: true  
>   \#api-server地址  
>     server: http://192.168.1.102:8080  
> ...  

**10-calico.conf**  
calico作为kubernets的CNI插件的配置
```xml
{  
  "name": "calico-k8s-network",  
  "cniVersion": "0.1.0",  
  "type": "calico",  
    <!--etcd的url-->
    "ed_endpoints": "http://192.168.1.102:2379",  
    "logevel": "info",  
    "ipam": {  
        "type": "calico-ipam"  
   },  
    "kubernetes": {  
        <!--api-server的url-->
        "k8s_api_root": "http://192.168.1.102:8080"  
    }  
}  
```


## 8. 小试牛刀
到这里最基础的kubernetes集群就可以工作了。下面我们就来试试看怎么去操作，控制它。
我们从最简单的命令开始，尝试一下kubernetes官方的入门教学：playground的内容。了解如何创建pod，deployments，以及查看他们的信息，深入理解他们的关系。
具体内容请看慕课网的视频吧：  [《Docker+k8s微服务容器化实践》][1]

## 9. 为集群增加service功能 - kube-proxy（工作节点）
#### 9.1 简介
每台工作节点上都应该运行一个kube-proxy服务，它监听API server中service和endpoint的变化情况，并通过iptables等来为服务配置负载均衡，是让我们的服务在集群外可以被访问到的重要方式。
#### 9.2 部署
**通过系统服务方式部署：**
```bash
#确保工作目录存在
$ mkdir -p /var/lib/kube-proxy
#复制kube-proxy服务配置文件
$ cp target/worker-node/kube-proxy.service /lib/systemd/system/
#复制kube-proxy依赖的配置文件
$ cp target/worker-node/kube-proxy.kubeconfig /etc/kubernetes/

$ systemctl enable kube-proxy.service
$ service kube-proxy start
$ journalctl -f -u kube-proxy
```
#### 9.3 重点配置说明
**kube-proxy.service**
> [Unit]  
Description=Kubernetes Kube-Proxy Server
...  
[Service]  
\#工作目录  
WorkingDirectory=/var/lib/kube-proxy  
ExecStart=/home/michael/bin/kube-proxy \\  
\#监听地址  
  --bind-address=192.168.1.103 \\  
  \#依赖的配置文件，描述了kube-proxy如何访问api-server  
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \\  
...

**kube-proxy.kubeconfig**
配置了kube-proxy如何访问api-server，内容与kubelet雷同，不再赘述。

#### 9.4 操练service
刚才我们在基础集群上演示了pod，deployments。下面就在刚才的基础上增加点service元素。具体内容见[《Docker+k8s微服务容器化实践》][1]。


## 10. 为集群增加dns功能 - kube-dns（app）
#### 10.1 简介
kube-dns为Kubernetes集群提供命名服务，主要用来解析集群服务名和Pod的hostname。目的是让pod可以通过名字访问到集群内服务。它通过添加A记录的方式实现名字和service的解析。普通的service会解析到service-ip。headless service会解析到pod列表。
#### 10.2 部署
**通过kubernetes应用的方式部署**
kube-dns.yaml文件基本与官方一致（除了镜像名不同外）。
里面配置了多个组件，之间使用”---“分隔
```bash
#到kubernetes-starter目录执行命令
$ kubectl create -f target/services/kube-dns.yaml
```
#### 10.3 重点配置说明
请直接参考配置文件中的注释。

#### 10.4 通过dns访问服务
这了主要演示增加kube-dns后，通过名字访问服务的原理和具体过程。演示启动dns服务和未启动dns服务的通过名字访问情况差别。
具体内容请看[《Docker+k8s微服务容器化实践》][1]吧~

[1]: https://coding.imooc.com/class/198.html
