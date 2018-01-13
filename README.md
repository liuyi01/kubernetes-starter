# 综述

  **必读：本项目+文档是专门针对慕课网的在线课程《微服务从开发到编排》中的kubernetes实战部分使用的，单独使用可能会有部分内容缺失和不易理解的地方，敬请谅解！**
  
&emsp;&emsp;对新手来说想要搭建一个完整的k8s集群还是比较难的，至少我第一次搭建的时候感觉就够复杂的，最正规的k8s集群构建方式是使用kube-admin，是官网正品，也是官方推荐的安装方式，执行一条命令，基本所有的事情都搞定，非常方便快捷，但前提是必须科学上网。但相信大部分同学都还是绿色的上网的环境。特别是你用来安装k8s的服务器，绝大部分是不具备科学上网的能力的。  
&emsp;&emsp;正是由于这个问题，社区也出现了非常多的自研的部署方案，经过一波波的迭代，也涌现了一些比较成熟的方案，像：tectonic-installer，kubespray，kismatic
即便是这些方案经过了时间的考验，他们也有各自的问题，首先就是不是太适合新手使用，即便安装过程的问题你都可以解决，安装完成后整个节点对你来说还是一个黑盒，不了解内部的模块和运行机制，当然使用kube-admin也会有同样的问题。还有就是有些方案本身的学习曲线就很高，有的不够灵活，想特殊配置的地方可能无法实现，还有是社区的力量有限，对于新功能的支持，他们的更新速度和支持的成熟度都不太好。  
&emsp;&emsp;本项目的主要目的就是让大家可以在绿色的网络环境下，愉快的安装k8s集群。一步步的手动安装，虽然过程有些繁琐，但这更有助于我们对k8s组件的理解，在集群出现问题的时候也更容易分析、定位。为了让各位新同学对kubernetes有一个良好的第一印象（如果让你们觉得kubernetes太太太复杂就不好了）我们尽量让部署过程简单，在初次安装时剥离了所有的认证和授权部分，并且把非必须组件放到最后。这样还可以让大家更容易抓住kubernetes的核心部分，把注意力集中到核心组件及组件的联系，从整体上把握kubernetes的运行机制。（当然后面我们还是会学习如何把认证授权部分加回来滴~）  
&emsp;&emsp;为了避免重复的操作和配置，我们也会引用一些脚本来帮我们做一些繁杂的工作，不过大家不用担心，我们会让大家知道脚本每一步都帮我们做了什么，即使你对脚本并不熟悉也会对k8s的整个搭建过程做到心中有数。  
&emsp;&emsp;当然除了环境搭建，我们还穿插了kubernetes的实践操作，从最简单的pod，deployments到service，到kube-dns。从使用命令到使用配置文件。了解熟悉了kubernetes的重要功能后，我们尝试把之前开发的微服务部署到kubernetes集群中。

## [一、预先准备环境][1]
## [二、基础集群部署 - kubernetes-simple][2]
## [三、完整集群部署 - kubernetes-with-ca][3]
## [四、在kubernetes上部署我们的微服务][4]
## [五、kubernetes重点功能实践][5]








  [1]: https://github.com/liuyi01/kube-cfgs/tree/master/docs/1-pre.md
  [2]: https://github.com/liuyi01/kube-cfgs/tree/master/docs/2-kubernetes-simple.md
  [3]: https://github.com/liuyi01/kube-cfgs/tree/master/docs/3-kubernetes-with-ca.md
  [4]: https://github.com/liuyi01/kube-cfgs/tree/master/docs/4-microservice-deploy.md
  [5]: https://github.com/liuyi01/kube-cfgs/tree/master/docs/5-import-func.md
