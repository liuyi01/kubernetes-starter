# 三、完整集群部署 - kubernetes-with-ca
## 1. 理解认证授权
#### 1.1 为什么要认证
想理解认证，我们得从认证解决什么问题、防止什么问题的发生入手。  
防止什么问题呢？是防止有人入侵你的集群，root你的机器后让我们集群依然安全吗？不是吧，root都到手了，那就为所欲为，防不胜防了。  
其实网络安全本身就是为了解决在某些假设成立的条件下如何防范的问题。比如一个非常重要的假设就是两个节点或者ip之间的通讯网络是不可信任的，可能会被第三方窃取，也可能会被第三方篡改。就像我们上学时候给心仪的女孩传纸条，传送的过程可能会被别的同学偷看，甚至内容可能会从我喜欢你修改成我不喜欢你了。当然这种假设不是随便想出来的，而是从网络技术现状和实际发生的问题中发现、总结出来的。kubernetes的认证也是从这个问题出发来实现的。
#### 1.2 概念梳理
为了解决上面说的问题，kubernetes并不需要自己想办法，毕竟是网络安全层面的问题，是每个服务都会遇到的问题，业内也有成熟的方案来解决。这里我们一起了解一下业内方案和相关的概念。
- **对称加密/非对称加密**
这两个概念属于密码学的东西，对于没接触过的同学不太容易理解。可以参考知乎大神的生动讲解：[《如何用通俗易懂的话来解释非对称加密》][1]
- **SSL/TLS**
了解了对称加密和非对称加密后，我们就可以了解一下SSL/TLS了。同样，已经有大神总结了非常好的入门文章：[《SSL/TLS协议运行机制的概述》][2]

#### 1.3 什么是授权
授权的概念就简单多了，就是什么人具有什么样的权限，一般通过角色作为纽带把他们组合在一起。也就是一个角色一边拥有多种权限，一边拥有多个人。这样就把人和权限建立了一个关系。
## 2. kubernetes的认证授权
Kubernetes集群的所有操作基本上都是通过kube-apiserver这个组件进行的，它提供HTTP RESTful形式的API供集群内外客户端调用。需要注意的是：认证授权过程只存在HTTPS形式的API中。也就是说，如果客户端使用HTTP连接到kube-apiserver，那么是不会进行认证授权的。所以说，可以这么设置，在集群内部组件间通信使用HTTP，集群外部就使用HTTPS，这样既增加了安全性，也不至于太复杂。  
对APIServer的访问要经过的三个步骤，前面两个是认证和授权，第三个是 Admission Control，它也能在一定程度上提高安全性，不过更多是资源管理方面的作用。
#### 2.1 kubernetes的认证
kubernetes提供了多种认证方式，比如客户端证书、静态token、静态密码文件、ServiceAccountTokens等等。你可以同时使用一种或多种认证方式。只要通过任何一个都被认作是认证通过。下面我们就认识几个常见的认证方式。
- **客户端证书认证**
客户端证书认证叫作TLS双向认证，也就是服务器客户端互相验证证书的正确性，在都正确的情况下协调通信加密方案。
为了使用这个方案，api-server需要用--client-ca-file选项来开启。
- **引导Token**
当我们有非常多的node节点时，手动为每个node节点配置TLS认证比较麻烦，这时就可以用到引导token的认证方式，前提是需要在api-server开启 experimental-bootstrap-token-auth 特性，客户端的token信息与预先定义的token匹配认证通过后，自动为node颁发证书。当然引导token是一种机制，可以用到各种场景中。
- **Service Account Tokens 认证**
有些情况下，我们希望在pod内部访问api-server，获取集群的信息，甚至对集群进行改动。针对这种情况，kubernetes提供了一种特殊的认证方式：Service Account。 Service Account 和 pod、service、deployment 一样是 kubernetes 集群中的一种资源，用户也可以创建自己的 Service Account。
ServiceAccount 主要包含了三个内容：namespace、Token 和 CA。namespace 指定了 pod 所在的 namespace，CA 用于验证 apiserver 的证书，token 用作身份验证。它们都通过 mount 的方式保存在 pod 的文件系统中。

#### 2.2 kubernetes的授权
在Kubernetes1.6版本中新增角色访问控制机制（Role-Based Access，RBAC）让集群管理员可以针对特定使用者或服务账号的角色，进行更精确的资源访问控制。在RBAC中，权限与角色相关联，用户通过成为适当角色的成员而得到这些角色的权限。这就极大地简化了权限的管理。在一个组织中，角色是为了完成各种工作而创造，用户则依据它的责任和资格来被指派相应的角色，用户可以很容易地从一个角色被指派到另一个角色。
目前 Kubernetes 中有一系列的鉴权机制，因为Kubernetes社区的投入和偏好，相对于其它鉴权机制而言，RBAC是更好的选择。具体RBAC是如何体现在kubernetes系统中的我们会在后面的部署中逐步的深入了解。
#### 2.3 kubernetes的AdmissionControl
AdmissionControl - 准入控制本质上为一段准入代码，在对kubernetes api的请求过程中，顺序为：先经过认证 & 授权，然后执行准入操作，最后对目标对象进行操作。这个准入代码在api-server中，而且必须被编译到二进制文件中才能被执行。
在对集群进行请求时，每个准入控制代码都按照一定顺序执行。如果有一个准入控制拒绝了此次请求，那么整个请求的结果将会立即返回，并提示用户相应的error信息。
常用组件（控制代码）如下：
- AlwaysAdmit：允许所有请求
- AlwaysDeny：禁止所有请求，多用于测试环境
- ServiceAccount：它将serviceAccounts实现了自动化，它会辅助serviceAccount做一些事情，比如如果pod没有serviceAccount属性，它会自动添加一个default，并确保pod的serviceAccount始终存在
- LimitRanger：他会观察所有的请求，确保没有违反已经定义好的约束条件，这些条件定义在namespace中LimitRange对象中。如果在kubernetes中使用LimitRange对象，则必须使用这个插件。
- NamespaceExists：它会观察所有的请求，如果请求尝试创建一个不存在的namespace，则这个请求被拒绝。

## 3. 环境准备
#### 3.1 停止原有kubernetes相关服务
开始之前我们要先把基础版本的集群停掉，包括service，deployments，pods以及运行的所有kubernetes组件
```bash
#删除services
$ kubectl delete services nginx-service

#删除deployments
$ kubectl delete deploy kubernetes-bootcamp
$ kubectl delete deploy nginx-deployment

#停掉worker节点的服务
$ service kubelet stop && rm -fr /var/lib/kubelet/*
$ service kube-proxy stop && rm -fr /var/lib/kube-proxy/*
$ service kube-calico stop

#停掉master节点的服务
$ service kube-calico stop
$ service kube-scheduler stop
$ service kube-controller-manager stop
$ service kube-apiserver stop
$ service etcd stop && rm -fr /var/lib/etcd/*
```
#### 3.2 生成配置（所有节点）
跟基础环境搭建一样，我们需要生成kubernetes-with-ca的所有相关配置文件
```bash
$ cd ~/kubernetes-starter
#按照配置文件的提示编辑好配置
$ vi config.properties
#生成配置
$ ./gen-config.sh with-ca
```
#### 3.3 安装cfssl（所有节点）
cfssl是非常好用的CA工具，我们用它来生成证书和秘钥文件  
安装过程比较简单，如下：
```bash
#下载
$ wget -q --show-progress --https-only --timestamping \
  https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
  https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
#修改为可执行权限
$ chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
#移动到bin目录
$ mv cfssl_linux-amd64 /usr/local/bin/cfssl
$ mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
#验证
$ cfssl version
```
#### 3.4 生成根证书（主节点）
根证书是证书信任链的根，各个组件通讯的前提是有一份大家都信任的证书（根证书），每个人使用的证书都是由这个根证书签发的。
```bash
#所有证书相关的东西都放在这
$ mkdir -p /etc/kubernetes/ca
#准备生成证书的配置文件
$ cp ~/kubernetes-starter/target/ca/ca-config.json /etc/kubernetes/ca
$ cp ~/kubernetes-starter/target/ca/ca-csr.json /etc/kubernetes/ca
#生成证书和秘钥
$ cd /etc/kubernetes/ca
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
#生成完成后会有以下文件（我们最终想要的就是ca-key.pem和ca.pem，一个秘钥，一个证书）
$ ls
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

## 4. 改造etcd

#### 4.1 准备证书
etcd节点需要提供给其他服务访问，就要验证其他服务的身份，所以需要一个标识自己监听服务的server证书，当有多个etcd节点的时候也需要client证书与etcd集群其他节点交互，当然也可以client和server使用同一个证书因为它们本质上没有区别。
```bash
#etcd证书放在这
$ mkdir -p /etc/kubernetes/ca/etcd
#准备etcd证书配置
$ cp ~/kubernetes-starter/target/ca/etcd/etcd-csr.json /etc/kubernetes/ca/etcd/
$ cd /etc/kubernetes/ca/etcd/
#使用根证书(ca.pem)签发etcd证书
$ cfssl gencert \
        -ca=/etc/kubernetes/ca/ca.pem \
        -ca-key=/etc/kubernetes/ca/ca-key.pem \
        -config=/etc/kubernetes/ca/ca-config.json \
        -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
#跟之前类似生成三个文件etcd.csr是个中间证书请求文件，我们最终要的是etcd-key.pem和etcd.pem
$ ls
etcd.csr  etcd-csr.json  etcd-key.pem  etcd.pem
```
#### 4.2 改造etcd服务
建议大家先比较一下增加认证的etcd配置与原有配置的区别，做到心中有数。
可以使用命令比较：
```bash
$ cd ~/kubernetes-starter/
$ vimdiff kubernetes-simple/master-node/etcd.service kubernetes-with-ca/master-node/etcd.service
```
**更新etcd服务：**
```bash
$ cp ~/kubernetes-starter/target/master-node/etcd.service /lib/systemd/system/
$ systemctl daemon-reload
$ service etcd start
#验证etcd服务（endpoints自行替换）
$ ETCDCTL_API=3 etcdctl \
  --endpoints=https://192.168.1.102:2379  \
  --cacert=/etc/kubernetes/ca/ca.pem \
  --cert=/etc/kubernetes/ca/etcd/etcd.pem \
  --key=/etc/kubernetes/ca/etcd/etcd-key.pem \
  endpoint health
```

## 5. 改造api-server
#### 5.1 准备证书
```bash
#api-server证书放在这，api-server是核心，文件夹叫kubernetes吧，如果想叫apiserver也可以，不过相关的地方都需要修改哦
$ mkdir -p /etc/kubernetes/ca/kubernetes
#准备apiserver证书配置
$ cp ~/kubernetes-starter/target/ca/kubernetes/kubernetes-csr.json /etc/kubernetes/ca/kubernetes/
$ cd /etc/kubernetes/ca/kubernetes/
#使用根证书(ca.pem)签发kubernetes证书
$ cfssl gencert \
        -ca=/etc/kubernetes/ca/ca.pem \
        -ca-key=/etc/kubernetes/ca/ca-key.pem \
        -config=/etc/kubernetes/ca/ca-config.json \
        -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
#跟之前类似生成三个文件kubernetes.csr是个中间证书请求文件，我们最终要的是kubernetes-key.pem和kubernetes.pem
$ ls
kubernetes.csr  kubernetes-csr.json  kubernetes-key.pem  kubernetes.pem
```
#### 5.2 改造api-server服务
**查看diff**
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/master-node/kube-apiserver.service kubernetes-with-ca/master-node/kube-apiserver.service
```
**生成token认证文件**
```bash
#生成随机token
$ head -c 16 /dev/urandom | od -An -t x | tr -d ' '
8afdf3c4eb7c74018452423c29433609

#按照固定格式写入token.csv，注意替换token内容
$ echo "8afdf3c4eb7c74018452423c29433609,kubelet-bootstrap,10001,\"system:kubelet-bootstrap\"" > /etc/kubernetes/ca/kubernetes/token.csv
```
**更新api-server服务**
```bash
$ cp ~/kubernetes-starter/target/master-node/kube-apiserver.service /lib/systemd/system/
$ systemctl daemon-reload
$ service kube-apiserver start

#检查日志
$ journalctl -f -u kube-apiserver
```

## 6. 改造controller-manager
controller-manager一般与api-server在同一台机器上，所以可以使用非安全端口与api-server通讯，不需要生成证书和私钥。
#### 6.1 改造controller-manager服务
**查看diff**
```bash
$ cd ~/kubernetes-starter/
$ vimdiff kubernetes-simple/master-node/kube-controller-manager.service kubernetes-with-ca/master-node/kube-controller-manager.service
```
**更新controller-manager服务**
```bash
$ cp ~/kubernetes-starter/target/master-node/kube-controller-manager.service /lib/systemd/system/
$ systemctl daemon-reload
$ service kube-controller-manager start

#检查日志
$ journalctl -f -u kube-controller-manager
```

## 7. 改造scheduler
scheduler一般与apiserver在同一台机器上，所以可以使用非安全端口与apiserver通讯。不需要生成证书和私钥。
#### 7.1 改造scheduler服务
**查看diff**
比较会发现两个文件并没有区别，不需要改造
```bash
$ cd ~/kubernetes-starter/
$ vimdiff kubernetes-simple/master-node/kube-scheduler.service kubernetes-with-ca/master-node/kube-scheduler.service
```
**启动服务**
```bash
$ service kube-scheduler start
#检查日志
$ journalctl -f -u kube-scheduler
```
## 8. 改造kubectl

#### 8.1 准备证书
```bash
#kubectl证书放在这，由于kubectl相当于系统管理员，我们使用admin命名
$ mkdir -p /etc/kubernetes/ca/admin
#准备admin证书配置 - kubectl只需客户端证书，因此证书请求中 hosts 字段可以为空
$ cp ~/kubernetes-starter/target/ca/admin/admin-csr.json /etc/kubernetes/ca/admin/
$ cd /etc/kubernetes/ca/admin/
#使用根证书(ca.pem)签发admin证书
$ cfssl gencert \
        -ca=/etc/kubernetes/ca/ca.pem \
        -ca-key=/etc/kubernetes/ca/ca-key.pem \
        -config=/etc/kubernetes/ca/ca-config.json \
        -profile=kubernetes admin-csr.json | cfssljson -bare admin
#我们最终要的是admin-key.pem和admin.pem
$ ls
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

#### 8.2 配置kubectl
```bash
#指定apiserver的地址和证书位置（ip自行修改）
$ kubectl config set-cluster kubernetes \
        --certificate-authority=/etc/kubernetes/ca/ca.pem \
        --embed-certs=true \
        --server=https://192.168.1.102:6443
#设置客户端认证参数，指定admin证书和秘钥
$ kubectl config set-credentials admin \
        --client-certificate=/etc/kubernetes/ca/admin/admin.pem \
        --embed-certs=true \
        --client-key=/etc/kubernetes/ca/admin/admin-key.pem
#关联用户和集群
$ kubectl config set-context kubernetes \
        --cluster=kubernetes --user=admin
#设置当前上下文
$ kubectl config use-context kubernetes

#设置结果就是一个配置文件，可以看看内容
$ cat ~/.kube/config
```

**验证master节点**
```bash
#可以使用刚配置好的kubectl查看一下组件状态
$ kubectl get componentstatus
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
```


## 9. 改造calico-node
#### 9.1 准备证书
后续可以看到calico证书用在四个地方：
* calico/node 这个docker 容器运行时访问 etcd 使用证书
* cni 配置文件中，cni 插件需要访问 etcd 使用证书
* calicoctl 操作集群网络时访问 etcd 使用证书
* calico/kube-controllers 同步集群网络策略时访问 etcd 使用证书
```bash
#calico证书放在这
$ mkdir -p /etc/kubernetes/ca/calico
#准备calico证书配置 - calico只需客户端证书，因此证书请求中 hosts 字段可以为空
$ cp ~/kubernetes-starter/target/ca/calico/calico-csr.json /etc/kubernetes/ca/calico/
$ cd /etc/kubernetes/ca/calico/
#使用根证书(ca.pem)签发calico证书
$ cfssl gencert \
        -ca=/etc/kubernetes/ca/ca.pem \
        -ca-key=/etc/kubernetes/ca/ca-key.pem \
        -config=/etc/kubernetes/ca/ca-config.json \
        -profile=kubernetes calico-csr.json | cfssljson -bare calico
#我们最终要的是calico-key.pem和calico.pem
$ ls
calico.csr  calico-csr.json  calico-key.pem  calico.pem
```

#### 9.2 改造calico服务
**查看diff**
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/all-node/kube-calico.service kubernetes-with-ca/all-node/kube-calico.service
```
> 通过diff会发现，calico多了几个认证相关的文件：  
/etc/kubernetes/ca/ca.pem  
/etc/kubernetes/ca/calico/calico.pem  
/etc/kubernetes/ca/calico/calico-key.pem  
由于calico服务是所有节点都需要启动的，大家需要把这几个文件拷贝到每台服务器上

**更新calico服务**
```bash
$ cp ~/kubernetes-starter/target/all-node/kube-calico.service /lib/systemd/system/
$ systemctl daemon-reload
$ service kube-calico start

#验证calico（能看到其他节点的列表就对啦）
$ calicoctl node status
```


## 10. 改造kubelet
我们这里让kubelet使用引导token的方式认证，所以认证方式跟之前的组件不同，它的证书不是手动生成，而是由工作节点TLS BootStrap 向api-server请求，由主节点的controller-manager 自动签发。
#### 10.1 创建角色绑定（主节点）
引导token的方式要求客户端向api-server发起请求时告诉他你的用户名和token，并且这个用户是具有一个特定的角色：system:node-bootstrapper，所以需要先将 bootstrap token 文件中的 kubelet-bootstrap 用户赋予这个特定角色，然后 kubelet 才有权限发起创建认证请求。
**在主节点执行下面命令**
```bash
#可以通过下面命令查询clusterrole列表
$ kubectl -n kube-system get clusterrole

#可以回顾一下token文件的内容
$ cat /etc/kubernetes/ca/kubernetes/token.csv
8afdf3c4eb7c74018452423c29433609,kubelet-bootstrap,10001,"system:kubelet-bootstrap"

#创建角色绑定（将用户kubelet-bootstrap与角色system:node-bootstrapper绑定）
$ kubectl create clusterrolebinding kubelet-bootstrap \
         --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
```
#### 10.2 创建bootstrap.kubeconfig（工作节点）
这个配置是用来完成bootstrap token认证的，保存了像用户，token等重要的认证信息，这个文件可以借助kubectl命令生成：（也可以自己写配置）
```bash
#设置集群参数(注意替换ip)
$ kubectl config set-cluster kubernetes \
        --certificate-authority=/etc/kubernetes/ca/ca.pem \
        --embed-certs=true \
        --server=https://192.168.1.102:6443 \
        --kubeconfig=bootstrap.kubeconfig
#设置客户端认证参数(注意替换token)
$ kubectl config set-credentials kubelet-bootstrap \
        --token=8afdf3c4eb7c74018452423c29433609 \
        --kubeconfig=bootstrap.kubeconfig
#设置上下文
$ kubectl config set-context default \
        --cluster=kubernetes \
        --user=kubelet-bootstrap \
        --kubeconfig=bootstrap.kubeconfig
#选择上下文
$ kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
#将刚生成的文件移动到合适的位置
$ mv bootstrap.kubeconfig /etc/kubernetes/
```
#### 10.3 准备cni配置
**查看diff**
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/worker-node/10-calico.conf kubernetes-with-ca/worker-node/10-calico.conf
```
**copy配置**
```bash
$ cp ~/kubernetes-starter/target/worker-node/10-calico.conf /etc/cni/net.d/
```
#### 10.4 改造kubelet服务
**查看diff**
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/worker-node/kubelet.service kubernetes-with-ca/worker-node/kubelet.service
```

**更新服务**
```bash
$ cp ~/kubernetes-starter/target/worker-node/kubelet.service /lib/systemd/system/
$ systemctl daemon-reload
$ service kubelet start

#启动kubelet之后到master节点允许worker加入(批准worker的tls证书请求)
#--------*在主节点执行*---------
$ kubectl get csr|grep 'Pending' | awk '{print $1}'| xargs kubectl certificate approve
#-----------------------------

#检查日志
$ journalctl -f -u kubelet
```

## 11. 改造kube-proxy
#### 11.1 准备证书
```bash
#proxy证书放在这
$ mkdir -p /etc/kubernetes/ca/kube-proxy

#准备proxy证书配置 - proxy只需客户端证书，因此证书请求中 hosts 字段可以为空。
#CN 指定该证书的 User 为 system:kube-proxy，预定义的 ClusterRoleBinding system:node-proxy 将User system:kube-proxy 与 Role system:node-proxier 绑定，授予了调用 kube-api-server proxy的相关 API 的权限
$ cp ~/kubernetes-starter/target/ca/kube-proxy/kube-proxy-csr.json /etc/kubernetes/ca/kube-proxy/
$ cd /etc/kubernetes/ca/kube-proxy/

#使用根证书(ca.pem)签发calico证书
$ cfssl gencert \
        -ca=/etc/kubernetes/ca/ca.pem \
        -ca-key=/etc/kubernetes/ca/ca-key.pem \
        -config=/etc/kubernetes/ca/ca-config.json \
        -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
#我们最终要的是kube-proxy-key.pem和kube-proxy.pem
$ ls
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```

#### 11.2 生成kube-proxy.kubeconfig配置
```bash
#设置集群参数（注意替换ip）
$ kubectl config set-cluster kubernetes \
        --certificate-authority=/etc/kubernetes/ca/ca.pem \
        --embed-certs=true \
        --server=https://192.168.1.102:6443 \
        --kubeconfig=kube-proxy.kubeconfig
#置客户端认证参数
$ kubectl config set-credentials kube-proxy \
        --client-certificate=/etc/kubernetes/ca/kube-proxy/kube-proxy.pem \
        --client-key=/etc/kubernetes/ca/kube-proxy/kube-proxy-key.pem \
        --embed-certs=true \
        --kubeconfig=kube-proxy.kubeconfig
#设置上下文参数
$ kubectl config set-context default \
        --cluster=kubernetes \
        --user=kube-proxy \
        --kubeconfig=kube-proxy.kubeconfig
#选择上下文
$ kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
#移动到合适位置
$ mv kube-proxy.kubeconfig /etc/kubernetes/kube-proxy.kubeconfig

```
#### 11.3 改造kube-proxy服务
**查看diff**
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/worker-node/kube-proxy.service kubernetes-with-ca/worker-node/kube-proxy.service
```
> 经过diff你应该发现kube-proxy.service没有变化

**启动服务**
```bash
#如果之前的配置没有了，可以重新复制一份过去
$ cp ~/kubernetes-starter/target/worker-node/kube-proxy.service /lib/systemd/system/
$ systemctl daemon-reload

#安装依赖软件
$ apt install conntrack

#启动服务
$ service kube-proxy start
#查看日志
$ journalctl -f -u kube-proxy
```

## 12. 改造kube-dns
kube-dns有些特别，因为它本身是运行在kubernetes集群中，以kubernetes应用的形式运行。所以它的认证授权方式跟之前的组件都不一样。它需要用到service account认证和RBAC授权。  
**service account认证：**  
每个service account都会自动生成自己的secret，用于包含一个ca，token和secret，用于跟api-server认证  
**RBAC授权：**  
权限、角色和角色绑定都是kubernetes自动创建好的。我们只需要创建一个叫做kube-dns的 ServiceAccount即可，官方现有的配置已经把它包含进去了。

#### 12.1 准备配置文件
我们在官方的基础上添加的变量，生成适合我们集群的配置。直接copy就可以啦
```bash
$ cd ~/kubernetes-starter
$ vimdiff kubernetes-simple/services/kube-dns.yaml kubernetes-with-ca/services/kube-dns.yaml
```
> 大家可以看到diff只有一处，新的配置没有设定api-server。不访问api-server，它是怎么知道每个服务的cluster ip和pod的endpoints的呢？这就是因为kubernetes在启动每个服务service的时候会以环境变量的方式把所有服务的ip，端口等信息注入进来。

#### 12.2 创建kube-dns
```bash
$ kubectl create -f ~/kubernetes-starter/target/services/kube-dns.yaml
#看看启动是否成功
$ kubectl -n kube-system get pods
```

## 13. 再试牛刀
终于，安全版的kubernetes集群我们部署完成了。  
下面我们使用新集群先温习一下之前学习过的命令，然后再认识一些新的命令，新的参数，新的功能。同样，具体内容请看[视频教程][3]吧~






[1]: https://www.zhihu.com/question/33645891/answer/57721969
[2]: http://www.ruanyifeng.com/blog/2014/02/ssl_tls.html
[3]: https://coding.imooc.com/class/198.html

