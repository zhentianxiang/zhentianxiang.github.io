---
layout: post
title: 理论-Kubernetes-08-Volcano GPU共享特性设计和使用
date: 2021-07-09
tags: 理论-Kubernetes
---

## Volcano GPU共享特性设计和使用

Volcano 是基于 Kubernetes 的批处理系统，方便HPC、 AI、大数据、基因等诸多行业通用计算框架接入，提供高性能任务调度引擎，高性能异构芯片管理，高性能任务运行管理等能力。本文通过介绍Volcano提供的GPU Share调度功能来助力HPC作业在Kubernetes集群中落地。

![](/images/posts/Linux-Kubernetes/Volcano-GPU共享特性设计和使用/1.png)

### GPU 共享问题

HPC是一个跨学科的多元化市场，包括化学研究，结构分析，地球物理学，可视化图像处理等领域，并且在大多数HPC应用领域都存在GPU加速的应用程序。据市场研究公司Intersect 360对HPC市场的调查数据，50个最受欢迎的HPC应用软件包中有34个提供GPU支持。

目前，Kubernetes已经成为容器编排的事实标准，容器集群服务商的Kubernetes平台都提供了GPU的调度能力，但通常是将整块GPU卡分配给容器。GPU在集群中属于稀缺资源，在某些场景下，这种独享的GPU资源的分配策略往往会导致GPU资源利用率偏低。Volcano提供调度层面的GPU资源共享，可以使多个Pod运行在同一块GPU卡上，从而提升集群GPU资源整体利用率。

### Volcano GPU共享设计

Volcano通过Kubernetes自定义扩展资源机制定义了GPU相关的“volcano.sh/gpu-memory”和“volcano.sh/gpu-number”两种资源，其中“volcano.sh/gpu-memory”用来描述节点GPU显存信息；“volcano.sh/gpu-number”用来描述节点GPU卡的数量。

Volcano通过Kubernetes提供的Device plugin实现如下功能：

- 收集集群中节点上gpu-number与显存gpu-memory
- 监控GPU健康状态
- 在集群中为申请GPU的workload挂载GPU资源

用户可以从Volcano device plugin for Kubernetes获取如何安装、使用volcano GPU插件的详细信息。

在集群部署GPU device plugin后，可以查看节点状态来查看节点上GPU显存与GPU卡数量信息：

> 
> Yaml文件
> 链接：http://blog.tianxiang.love:8080/HyperAI/4-Volcano-GPU-share/pod-GPU-share-gpu.yml

```javascript

$ kubectl apply -f volcano-v1.1.0.yaml

$ kubectl get pods -n volcano-system 
NAME                                   READY   STATUS      RESTARTS   AGE
volcano-admission-6674c7f675-9njg8     1/1     Running     0          4h37m
volcano-admission-init-jp8zg           0/1     Completed   0          4h37m
volcano-controllers-78798d5fd9-n74tw   1/1     Running     0          4h37m
volcano-scheduler-7684cb5c7-ztzzf      1/1     Running     0          4h37m

$ kubectl apply -f volcano-device-plugin.yaml

$ kubectl get pods -n kube-system |grep volcano
volcano-device-plugin-d6kbc                1/1     Running   0          61m
volcano-device-plugin-qrqvv                1/1     Running   0          61m

$ kubectl get nodes
NAME        STATUS   ROLES    AGE   VERSION
hyperai     Ready    <none>   16d   v1.18.19
master198   Ready    master   16d   v1.18.19
node199     Ready    <none>   16d   v1.18.19

$ kubectl edit node hyperai

193 status:
194   addresses:
195   - address: 192.168.11.200
196     type: InternalIP
197   - address: hyperai
198     type: Hostname
199   allocatable:
200     cpu: "56"      #56核CPU
201     ephemeral-storage: "860741423727"
202     hugepages-1Gi: "0"
203     hugepages-2Mi: "0"
204     memory: 263922448Ki
205     nvidia.com/gpu: "2"      #2个显卡
206     pods: "110"     #默认运行110个pod
207     volcano.sh/gpu-memory: "21978"   #显存大小
208     volcano.sh/gpu-number: "2"   #当前节点显卡数量
209   capacity:
210     cpu: "56"
211     ephemeral-storage: 933964220Ki
212     hugepages-1Gi: "0"
213     hugepages-2Mi: "0"
214     memory: 264024848Ki
215     nvidia.com/gpu: "2"
216     pods: "110"
217     volcano.sh/gpu-memory: "21978"
218     volcano.sh/gpu-number: "2"
219   conditions:
```

工作流程

![](/images/posts/Linux-Kubernetes/Volcano-GPU共享特性设计和使用/2.png)

**（1）GPU device plugin收集并上报GPU资源：**

Device plugin通过nvml库可以查询节点上GPU卡的数量和显存信息。通过Kubernetes提供的ListAndWatch功能将以上收集到的扩展资源信息通过kubelet报告给API Server。同时，device plugin提供GPU健康状态检查功能，当某块GPU卡出现异常的情况下，可以及时更新集群资源信息。

**（2）用户提交申请8000MB GPU显存的Pod到Kube-APIServer。**

**（3）Volcano GPU调度插件：**

- Volcano通过ConfigMap对调度器进行配置，可以在“volcano-scheduler-configmap”开启GPU share功能：

```javascript
$ kubectl edit cm -n volcano-system volcano-scheduler-configmap
  1 # Please edit the object below. Lines beginning with a '#' will be ignored,
  2 # and an empty file will abort the edit. If an error occurs while saving this file will be
  3 # reopened with the relevant failures.
  4 #
  5 apiVersion: v1
  6 data:
  7   volcano-scheduler.conf: |
  8     actions: "enqueue, allocate, backfill"
  9     tiers:
 10     - plugins:
 11       - name: priority
 12       - name: gang
 13       - name: conformance
 14     - plugins:
 15       - name: drf
 16       - name: predicates
 17         arguments:
 18           predicate.GPUSharingEnable: true       #开启GPU共享功能
 19       - name: proportion
 20       - name: nodeorder
 21       - name: binpack
```

- Predicates插件提供节点的预选功能，在enable GPU sharing功能的情况下会过滤出GPU节点，并选出能够满足当前pod资源申请的GPU卡id。例如：当前集群包含三个节点，其中Node1和Node2每台机器包含2张11178MB显存的GPU卡，Node3不包含GPU卡。当用户创建一个Pod请求80000MB显存资源的时候，调度器首先过滤出包含GPU资源的节点Node1和Node2，然后在节点中选取一张GPU能够满足Pod请求的资源进行调度。在该例子中，Volcano将会为该Pod选取Node2中的GPU1卡进行调度。

![](/images/posts/Linux-Kubernetes/Volcano-GPU共享特性设计和使用/3.png)

- 在调度器为Pod选定节点以及GPU卡之后，会在该Pod的annotation增加GPU的“volcano.sh/gpu-index”和“volcano.sh/predicate-time”。其中“volcano.sh/gpu-index”为GPU卡信息，“volcano.sh/predicate-time”为predicate时间。最后调度器调用Kubernetes Bind API将节点和Pod进行绑定。

**(4）启动容器：**

节点上的Kubelet在收到Pod和节点绑定时间后，会创建Pod实体，Kubelet调用GPU plugin中实现的Allocate方法。该方法首先在节点所有pending状态的pod中选取出“volcano.sh/gpu-assigned”为false且predicate时间最早的pod进行创建，并更新该pod的“volcano.sh/gpu-assigned”为true。

使用GPU Share功能

提交gpu-pod1和gpu-pod2两个pod，分别请求1024MB GPU显存。利用Volcano GPU share调度功能，将两个pod调度到同一个GPU卡上。

```javascript
$ kubectl create ns volcano-pod
$ vim pod-GPU-share-gpu.yml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod1
  namespace: volcano-pod
spec:
  schedulerName: volcano
  containers:
  - name: cuda-container-1
    image: nvidia/cuda:10.1-base-ubuntu18.04
    command: ["sleep"]
    args: ["100000"]
    # requesting 1024MB GPU memory
    resources:
      limits:
        volcano.sh/gpu-memory: 1024  #分配pod为1024的显存
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod2
  namespace: volcano-pod
spec:
  schedulerName: volcano
  containers:
  - name: cuda-container-2
    image: nvidia/cuda:10.1-base-ubuntu18.04
    command: ["sleep"]
    args: ["100000"]
    # requesting 1024MB GPU memory
    resources:
      limits:
        volcano.sh/gpu-memory: 1024  #分配pod为1024M的显存

$ kubectl apply -f pod-GPU-share-gpu.yml
```

查看pod运行情况：
```javascript
$ kubectl get pods -n volcano-pod 
NAME       READY   STATUS    RESTARTS   AGE
gpu-pod1   1/1     Running   0          39m
gpu-pod2   1/1     Running   0          33m
```
查看gpu-pod1环境变量，该pod被分配到GPU0卡上运行：
```javascript
$ kubectl exec -it -n volcano-pod gpu-pod1 -- env |grep -E "GPU|NVIDIA_VISIBLE_DEVICES"
NVIDIA_VISIBLE_DEVICES=0
VOLCANO_GPU_TOTAL=10989
VOLCANO_GPU_ALLOCATED=1024
```
查看gpu-pod2环境变量，该pod被分配到GPU0卡上运行：
```javascript
$ kubectl exec -it -n volcano-pod gpu-pod2 -- env |grep -E "GPU|NVIDIA_VISIBLE_DEVICES"
NVIDIA_VISIBLE_DEVICES=0
VOLCANO_GPU_TOTAL=10989
VOLCANO_GPU_ALLOCATED=1024
```
查看节点GPU显存分配情况：
```javascript
$ kubectl describe nodes hyperai
llocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource               Requests      Limits
  --------               --------      ------
  cpu                    4550m (8%)    6 (10%)
  memory                 19656Mi (7%)  19956Mi (7%)
  ephemeral-storage      0 (0%)        0 (0%)
  hugepages-1Gi          0 (0%)        0 (0%)
  hugepages-2Mi          0 (0%)        0 (0%)
  nvidia.com/gpu         0             0
  volcano.sh/gpu-memory  2048          2048  #由此可见，已经给pod分配了2048M的显存了
  volcano.sh/gpu-number  0             0
Events:                  <none>
```

通过上述结果可以看出，Volcano GPU共享功能可以把多个Pod调度到相同的GPU卡上，达到GPU显存share的目的，从而提升集群GPU资源整体利用率。

如果想要在Volcano中使用GPU Share功能运行HPC作业，只需要将https://github.com/volcano-sh/volcano/blob/master/example/integrations/mpi/mpi-example.yaml 例子中的image替换为支持GPU的image，同时为worker任务指定“volcano.sh/gpu-memory”就可以使用了。

【参考文献】

*1.https://github.com/volcano-sh/volcano/blob/master/docs/user-guide/how_to_use_gpu_sharing.md*

*2. https://github.com/volcano-sh/devices*

*3. https://github.com/volcano-sh/volcano*

深入了解Volcano
