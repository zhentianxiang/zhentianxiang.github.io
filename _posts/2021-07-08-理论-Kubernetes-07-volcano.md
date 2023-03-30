---
layout: post
title: 理论-Kubernetes-07-volcano
date: 2021-07-08
tags: 理论-Kubernetes
---

### Volcano基于Kubernetes的batch任务管理及调度系统

![](/images/posts/Linux-Kubernetes/volcano/1.png)

Volcano是一款构建与kubernetes**之上**的增强型高性能计算任务批量处理系统。作为一个面向高性能计算场景的平台，它弥补了kubernetes在机器学习、深度学习、HPC、大数据计算等场景下的基本能力缺失，其中包括gang-schedule的调度能力、计算任务队列管理、task-topology和GPU亲和性调度。另外，volcano在原生kubernetes能力基础上对计算任务的批量创建及生命周期管理、fair-share、binpack调度等方面做了增强。

> 换句话说：volcano解决了k8s部分功能相对部分专业服务的不足之处。

![](/images/posts/Linux-Kubernetes/volcano/2.png)

### Volcano架构

Volcano在原生Kubernetes Job对象之上，引入一个新的CRD对象“job.batch.volcano.sh”，以下统称为“vcjob”，其中包含了对任务执行信息配置的描述和任务执行过程中生命周期的控制参数。作为一款通用的基于kubernetes的对象管理工具，volcano在支持“vcjob”及其所管理Pod的生命周期管理的同时，同样可以处理原生Kubernetes Pod对象的管理。

> 换句话说：volcano是k8s中一个对象资源，功能比原生的job更为牛逼。

**中英互译**

> CRD：资源对象
>
> volcano-admission：volcano管理员(权限允许)
>
> volcano-controllers：volcano控制器
>
> volcano-scheduler：volcano调度器
>
> admission webhook：入口网钩
>
> Mutating：转换修改
>
> Validating：验证
>
> queue：队列
>
> podgroup：POD 组
>
> command：命令
>
> task：任务
>
> minAvailable：可用的
>
> policies：政策(生命周期)
>
> policy：政策
>
> event：事件
>
> action：动作
>
> PodFailed：POD失败
>
> PodEvicted：POD驱逐
>
> TaskCompleted：任务已完成
>
> AbortJob：中止停止
>
> RestartJob：重新启动
>
> TerminateJob：中止作业
>
> CompleteJobJob：完成动作
>
> ResumeJob：总结工作
>
> RestartTask：重新起启动任务
>
> headless service：无头服务
>
> subDomain：子域
>
> priorityClassName：优先配置
>
> weight：重量权重
>
> capability：能力上限

Volcano由三个组件组成，分别是volcano-admission，volcano-controllers，volcano-scheduler。Volcano-admission是Kubernetes的一个admission webhook，包括Mutating控制器和Validating控制器两部分，其中Validating控制器负责创建、更新“vcjob”对象之前的校验工作；Mutating控制器负责创建“vcjob”对象时修改对象的部分参数，为部分对象参数添加默认值。Volcano-controllers是针对自定义CRD对象“vcjob”、queue、podgroup和command的Kubernetes Controller控制器，用于监听和处理上述对象的创建，销毁等生命周期。其中queue是volcano中资源管理对象，podgroup是volcano中资源调度的单位，command是封装了对“vcjob”和queue进行生命周期管理的对象。Volcano-schedules负责kubernetes pod的调度。Volcano-scheduler中的调度策略均是通过插件形式注入到volcano中，以保证调度通用性。为了便于管理“vcjob”，queue，podgroup和command对象，volcano提供vcctl工具用于操作上述对象。

一个“vcjob”的处理流程大致如下：当用户通过vcctl工具或者kubectl工具创建了一个“vcjob”对象。Volcano-controllers监听到“vcjob”的创建，并开始处理“vcjob”对象，按照“vcjob”内的配置先后创建Pod，并根据“vcjob”中配置的插件为“vcjob”创建对应的依赖资源，依赖的资源可能是ConfigMap、Secret、Service等，同时在创建Pod的时候，为Pod挂载对应资源卷。Volcano-scheduler监听到集群中有新的Pod创建，开始为Pod执行调度动作，并最终为Pod选择合适的节点。最后，kubelet检测到节点上有Pod需要运行，开始运行Pod。至此，“vcjob”生命周期的处理过程结束。

![](/images/posts/Linux-Kubernetes/volcano/3.png)

### Volcano Job 解析

Volcano在原生Kubernetes Job对象基础上扩展引入新的CRD对象“vcjob”。“vcjob”是一个更强大的batch job管理对象，在Kubernetes原生Job基础上做了很多加强。其中，在配置管理方面，支持多task模式，用于将同一批次计算任务中不同类型Pod划分到一个Kubernetes对象内进行管理，task是对Pod描述信息的封装。在Job生命周期管理方面，支持用户自定义Job级别和task级别生命周期管理策略，提升计算过程的自动化程度。在数据传输和共享方面，支持Job下Pod共享存储卷。支持为“vcjob”配置插件来适配不同的计算框架，降低用户使用不同框架进行计算的学习成本和减少搭建框架依赖资源的重复工作。在资源管理方面，支持用户将任务放置在不同的queue下，细化资源划分粒度，确保资源使用的多租性。

一个“vcjob”配置描述如下所示：

```sh
apiVersion: batch.volcano.sh/v1alpha1  
kind: Job  
metadata:  
name: demo-vc-job  
spec:  
# minAvailable配置，用于标识Job下Pod调度过程中的最小调度单位  
minAvailable: 3  
# schedulerName用于标明Job下Pod的调度器  
# 选择volcano调度器可享用volcano调度器在计算领域的加强功能  
# 选择default-scheduler将使用Kubernetes默认调度器调度  
schedulerName: volcano  
# 插件列表，用于在兼容不同计算框架时，配置使用公共资源  
plugins:  
ssh: []  
svc: []  
# policies定义Job级别的生命周期管理  
policies:  
  # event定义生命周期中的事件名称  
- event: TaskCompleted  
  # action定义生命周期中的action名称  
  action: CompleteJob  
# queue配置Job下Pod的queue名称，用于集群资源划分  
queue: default  
# tasks列表，支持多task模式  
tasks:  
  # replicas定义同类型计算Pod的副本数  
- replicas: 1  
  name: mpimaster  
  # policies配置，定义task级别生命周期管理  
  policies:  
    - event: TaskCompleted  
      action: CompleteJob  
  # template是Kubernetes podTemplate对象  
  template:
    ······  
- replicas: 2  
  name: mpiworker  
  template:
    ······ 
```

Task是Kubernetes podTemplate的封装，“vcjob”支持多task模式。“vcjob”支持一个Job中配置多个具有不同配置的podTemplate，并且，每个podTemplate可以分别配置副本数。Tasks的引入，提供了对Pod的批量管理能力，满足了深度学习场景下不同角色Pod的创建和管理。

“minAvailable”字段，标识当前Job下Pod调度过程中需要保证的最小调度单位。“minAvailable”需要大于等于1并且小于等于Job下所有实例个数和。该字段与volcano-scheduler中的gang-scheduler调度策略组合，可以实现调度过程中的“All or nothing”调度策略。如果“minAvailable”的数值为2，则表明当调度器为Job下的Pod执行调度的时候，只有集群资源满足其中任何两个Pod的调取要求，调度动作才可以执行，这些满足调度要求的Pod可以被调度。否则，将跳过对该Job下Pod的调度流程，即使Job下某些Pod的调度要求得到满足，调度器也不会为这些Pod执行调度动作。

“policies”用于定义任务生命周期管理的参数，它是一个数组，支持同时定义多种不同的生命周期管理策略。“policy”由“event”和“action”两部分组成，其中“event”表明Pod上报的事件，“action”表明Pod事件期望触发的动作。目前支持定义的Pod “event”包括“PodFailed”，“PodEvicted”，“TaskCompleted”。支持配置的Job “action”包括“AbortJob”，“RestartJob”，“TerminateJob”，“CompleteJob”, “ResumeJob”。支持配置的task “action”为“RestartTask”。通过以上配置，“vcjob”支持在Pod失败、Pod被驱逐或者task完成后，触发Job停止、重启和完成等动作。“vcjob”支持在Job级别和task级别分别配置policies，其中Job级别policies配置对Job下的所有Pod生效，task级别的policies对当前task下的Pod生效。“vcjob”的生命周期管理模式契合了深度学习场景下对计算任务的生命周期管理述求。

另外，“vcjob”中的policies使用，并不局限于在“policies”中做对应配置，还可以通过volcano引入的CRD对象command触发。“command”是辅助管理其他对象生命周期的一个对象，它封装了对象target和针对target实施的policies两部分。

一个command对象实体如下所示：

```sh
apiVersion: bus.volcano.sh/v1alpha1  
kind: command  
metadata:  
name: command-job  
# action定义将对target对象的处理动作  
action: RestartJob  
# target定义command的处理对象  
target:  
apiVersion: job.batch.volcano.sh/v1alpha1  
controller: true  
kind: Job  
name: demo-job  
uid: d7e5c85f-e1e0-11e9-a589-fa163e5227bc  
```

Volcano-controllers将负责处理针对“vcjob”和queue的command对象，解析其中的target并实施对target的action。此外，volcano vcctl工具对“vcjob”和queue的管理也将通过command施加于对应的“vcjob”对象上。

“vcjob”支持配置使用插件，兼容不同计算框架任务的运行。插件可以辅助创建除Pod资源之外的其他资源，并为Pod挂载所需物料。目前volcano支持“ssh”，“svc”，“env”三种插件。其中“ssh”插件为Job下的Pod配置ssh免密认证证书。配置使用“ssh”插件，可以实现Pods之间的免密ssh互访，这对于mpi类作业至关重要。“svc”插件为job创建headless service，并为Job下的Pod配置hostName和subDomain名称，其中Service名称、Job名称和subDomain名称一致，这样Kubernetes CoreDNS将为Job下的每个Pod映射一个podName.subDomain的域名，并指向Pod的IP地址。为每个计算节点暴露访问地址，这是Tensorflow和MXNet等计算框架计算节点形成计算集群的必要条件。“env”插件为每个Pod设置“VK_TASK_INDEX”环境变量，通过该环境变量，可以获取Pod在同类型计算任务Pod列表中的序号。这可以满足Tensorflow计算中，获取每个计算任务序号的需求。

提供priorityClassName配置，用来指明Job级别的优先级。Pod调度中有多个优先级维度，其中Job级别的priorityClassName决定了Job下Pod的整体调度顺序，在调度过程中，具有高优先级的Job下的Pod将会被优先调度。

### Queue解析

Queue是一种划分集群资源的对象，用户可以通过queue分割集群资源，达到平衡任务优先级和集群资源的目的。Queue是集群级别，它可以跨越多个namespace，不同的namespace可以共用同一个queue，不同的pod也可以共享同一个queue下的资源。Queue根据自身配置和集群现状分得资源配额，其下的Job根据优先级逐个获取queue的资源，当queue下的资源被占满后，其下未获取到集群资源的Pod将无法再继续被调度，直到queue下已经在运行的Pod结束并释放资源。

在“vcjob”中，queue的配置为Job级别，通过为“vcjob”配置“queue”参数指明Job所在的queue。Queue的配置对Job下的所有Pod生效，不支持Job下的Pod使用不同的queue。在安装部署volcano时，系统为集群创建default queue，用于为没有明确指定queue的Job提供默认queue，集群下发的“vcjob”，如果没有指定queue名称，将使用默认default queue。对于集群下非“vcjob”对象创建的pod，比如Deployment对应的Pod，默认也放置到default queue下。

系统根据queue的配置和集群可分配的资源为queue分配资源。Queue有两个配置，weight和capability，其中weight表示queue占有资源的权重，capability为queue可以占有的资源上限。理论上，queue可以分配的资源为(weight/totalWeight)*allocatableResource和queue下所有Pod请求资源总和的最小值，weight是当前queue的权重，totalWeight为集群下所有含有运行中Pod或待调度pod queue的权重总和，allocatableResource为集群下可分配资源。在实际资源分割中，queue的资源分割将经历多个轮次，直到集群下的资源分割完毕，这样可以保证当集群下weight值比较高的queue下任务比较少，但是weight值比较低的queue下任务比较多时，weight值比较低的queue仍然可以使用集群下剩余的资源，即使这部分资源已经超出了严格按照queue权重算出的queue资源配额。当queue配置了capability参数后，实际queue可以使用的资源由上述计算的数值和capability两者的最小值决定。使用Queue分割集群资源，不仅可以为每个租户提供资源配额的保证，还可以保证集群下租户使用集群资源的弹性。正常情况下，租户可以使用的集群资源上限为queue分得的资源配额，当租户使用的资源达到资源配额后，如果此时集群下仍有剩余资源，租户仍然可以使用这部分资源。

根据queue的weight为queue分配集群资源的逻辑如下图所示。分配配额的过程是一个循环，首先计算所有queue的weight之和，在计算queue weight之和时，剔除已经meet的queue，queue meet表示queue下的资源请求已经得到满足。根据queue的weight所占比重计算初始queue配额值，当计算所得queue配额值大于queue下资源请求量时，queue的配额被调整为queue下的资源请求量，并标记该queue为meet。当所有的queue都已经被分配了配额后，判断计算集群剩余资源是否为0，如果为0则资源分配终止，否则继续新一轮的资源分配。当所有的queue都meet时，集群资源分配也会终止。

![](/images/posts/Linux-Kubernetes/volcano/4.png)

当Queue下已经分配的资源大于或等于queue可支配的资源，此时queue处于“overUsed”的状态，queue下的Pod将不会再被调度，Queue下已经调度的Pod不会受到影响。当queue的配置中配置了capability，如果Pod所在Job需求的最小资源与queue下已经分配的资源的和大于queue可支配的资源总量，Pod将因为没有足够的资源而不能被调度。

Queue按照weight分配集群资源，正常情况下，queue下Pod所使用的资源不能超过queue所分得的配额，保证了集群资源使用的多租性。Queue灵活分配集群资源，有任务运行或调度的queue动态瓜分集群资源，保证了集群下用户可以灵活使用剩余资源。无论是何种场景，配额并不代表实际可以使用的资源量，这还取决于集群下空闲资源的数量，尽管queue分得了资源配额，但是当集群下空闲资源不足时，queue下的Pod仍然无法被调度，尤其是当集群下划分资源的对象发生增删变化时，配额和实际可使用的计算资源并不能保证一一对应。那么，当集群下出现queue的增删，queue下租户的资源配额所对应的实际资源是如何得到保障的呢？Volcano引入“reclaim” action，用于保障集群下queue的配额所代表的资源即是queue下任务所能使用的资源。当集群中新增queue，新增的queue按照weight分得资源配额，如果集群下空闲资源小于queue的资源配额，这个新增的queue会尝试通过“reclaim”行为从那些资源使用量大于queue配额的queue中抢占资源。通过“reclaim”的过程，保证集群下所有的queue可以使用的资源都在配额左右。

### PodGroup解析

PodGroup是volcano引入的一个新的CRD对象，它是volcano-scheduler调度过程中的一个单位，与Job对应，在Pod调度之上，并贯穿于Pod调度的整个过程中。PodGroup与Pod绑定在一起，实现Pod的整体调度，比如与gang-scheduler插件一起实现Pod的“All or nothing”调度策略。PodGroup在调度中的角色是不可或缺的，Pod通过在annotation中指定“scheduling.k8s.io/group-name”与对应的podgroup绑定在一起。Podgroup的配置中包含“minMember”、“queue”、“priorityClassName”和“minResources”字段。其中“minMember”和“minResources”用于表明Job下的Pod整体调度时的最小资源申请量，只有当Pod所在Job下的最小资源申请量得到满足，Job下的Pod才能被调度。“queue”字段表明Pod所在的queue。“priorityClassName”字段表明Pod所在Job的优先级，具有高优先级的Job下的Pod具有高的调度优先级。在“vcjob”的处理过程中，volcano会为其创建podgroup，并将Job所对应的Pod与该podgroup绑定。对于普通的Pod，如果指定了volcano调度器，volcano-controllers也会为其创建一个podgroup，并将创建的podgroup与该pod绑定。同时，volcano支持先创建podgroup，并将Pod与已有的podgroup绑定，这只需要在Pod的annotation中做对应配置。

另外，podgroup的状态也决定了Job下的Pod是否能够被调度，为了防止往集群下恶意投放多个Pod，导致在集群资源不足时，volcano-scheduler调度器仍然需要反复处理多个未调度的Pod，造成调度器的空跑，性能下降。只有当podgroup的状态为非Pending状态时，podgroup下的Pod才允许被调度。

### Volcano调度框架

Volcano的调度过程以action和plugin为基础。其中，action中定义了调度过程中将对Pod实施的调度阶段，plugin中注册了各种调度算法，调度算法包括节点的预选算法，优选算法或者资源管理控制和计算的其他逻辑。Plugin中注册的调度算法将分散到action的处理过程中执行。Volcano的调度会无限循环进行多个轮次，在每个调度轮次中，volcano open一个新的session，并在session中遍历注册的action并执行，在每个action中，按照各层级优先级，遍历需要调度的Pod，并逐个为Pod执行对应的action。在Pod调度过程中，将会调用plugin中注册的函数。在本轮次调度结束后，session将被closed。在下一个调度轮次中开启新的session进行调度。

![](/images/posts/Linux-Kubernetes/volcano/5.png)

Volcano目前支持“enqueue”、“allocate”、“backfill”、“preempt”、“reclaim”五个action。在一个调度过程中执行哪些action，这取决于调度器的配置，但是一般来说，“enqueue”、“allocate”和“backfill”三个action是必不可少的。

“enqueue” action用于刷新podgroup的状态，将podgroup的状态由“Pending”刷新成“Inqueue”。当一个Job下的最小资源申请量不能得到满足时，这表明，即使为Job下的Pod执行调度动作，Pod也会因为gang约束没有达到而无法调度。因此，在这种场景下，volcano-scheduler不会刷新podgroup的状态，podgroup的状态保持为“Pending”，对于状态为“Pending”的podgroup下的Pod，后续action都不再处理。即是，如果一个Pod所在Job的podgroup状态为“Pending”，那么这个Pod将不会被调度。当集群下剩余资源满足Job的最小资源述求，调度器会刷新Job的podgroup状态为“Inqueue”，表明podgroup下的Pod可以被尝试调度。“enqueue”action用于防止集群下有大量不能调度的Pod，影响scheduler的调度性能。

“allocate” action用于处理待调度Pod列表中具有资源申请量的Pod调度，即non-besteffort pod的调度。与Kubernetes默认default-scheduler类似，allocate action在为Pod选择节点调度时，也需要经过“predicate”和“prioritize”两个阶段，在经历节点预选后，从预选节点中选择一个最优的节点，并将Pod调度上去。在预选和优选的过程中，调度器将会调用plugin中注册的预选和优选函数。在allocate action的执行过程中，在预选节点的阶段，单单从节点对Pod资源请求量的满足方面来看，只要节点上空闲资源或者releasing资源大于Pod的资源申请量，就认为该节点的资源状况满足Pod的资源调度请求，当其他预选条件也同时满足时，该节点将作为优选阶段的候选节点供Pod调度。节点的releasing资源是指节点上正在结束或被驱逐的Pod所占用的资源。理论上，当Pod结束或被驱逐后，这部分节点资源可以被释放，供其他Pod使用。在为Pod选择合适的节点后，如果Pod的资源申请量小于节点的空闲资源，将会为Pod执行绑定动作，如果Pod的资源申请量大于Node的空闲资源，但是小于节点的releasing资源，Pod会被pipelined到节点上。Pipelined是指Pod作为候选Pod调度到这个节点上，一旦节点上有了空闲的资源，被pipelined的Pod将会被绑定到这个节点上。“allocate”过程遵循commit机制，当一个Pod的调度请求得到满足后，最终并不一定会为该Pod执行绑定动作，这还取决于Pod所在Job的gang约束是否得到满足，只有Pod所在Job的gang约束得到满足，Pod才可以被调度，否则，Pod不能够被调度。

“backfill” action处理待调度Pod列表中没有指明资源申请量的Pod调度，即besteffort pod的调度。在对单个Pod执行调度动作的时候，遍历所有的节点，只要节点满足了Pod的调度请求，就将Pod调度到这个节点上。

“preempt” action用于处理高优先级pod的调度问题。当集群比较繁忙，集群下已经没有空闲资源可供新Pod使用，此时，如果有更高优先级的Pod下发到集群中，那么volcano-scheduler会尝试驱逐这个集群中已经处于运行中的并且优先级比待调度Pod低的Pod，希望通过驱逐低优先级的Pod，使更高优先级的Pod得以调度。当然考虑到驱逐将可能对已经处于运行中的任务有破坏性的影响，对于一个Pod是否可以驱逐其他的Pod，或者一个Pod是否可以被其他的pod驱逐都有严格的限制。比如在一个Pod是否可以驱逐其他Pod的约束中，只有当Pod驱逐了其他Pod后，这个Pod所在Job的gang约束可以得到满足，Pod才可以驱逐其他Pod。对于一个Pod是否可以被驱逐的约束将包括，Pod被驱逐后，Pod所在Job的gang约束不能被破坏，在kube-system下的Pod不能被驱逐等。当一个Pod驱逐其他的Pod成功后，这个Pod将会pipelined到这个节点上，预示着，当节点上有空闲资源时，Pod将会被调度到这个节点上。

“reclaim” action用于在各个queue之间均衡集群资源。queue在瓜分集群资源时，只会考虑现有集群下有任务在运行或待调度的queue。当集群中现有的queue瓜分完集群资源后，集群下新增了queue，这个queue将希望得到集群资源。集群资源划分需要打破原来的形势，建立新的分割形势。当这个新加入的queue分割到集群配额后，部分原有queue的配额将可能会降低。然而，新queue分到配额后，并不表明queue下的Pod可以正常调度了，因为queue在此时分到的配额只是使用集群资源的上限，并不是使用集群的担保。假如此时旧有queue下的Pod已经占尽了集群资源，尽管此时这些queue下pod的资源使用量已经大于queue分得的配额，但是因为这些Pod已经处于运行中，并不会主动释放资源。这时候，新的queue虽然有配额，但是苦于集群下没有资源，queue下的Pod仍然无法调度。这个时候就需要reclaim action在不同的queue之间做资源均衡。“reclaim” action尝试驱逐那些资源使用量已经大于配额的queue下的Pod，并把这部分资源分配给资源使用量还没有得到满足的queue。同样在Pod驱逐过程中，对于是否可以驱逐和是否可以被驱逐都有严格的定义。只有当Pod被驱逐后，其所在Job下的资源使用量仍然大于配额，这个Pod才可以被驱逐，以防止queue之间出现互相驱逐的震荡。同样，只有当Pod所在Job的gang约束没有得到破坏时，Pod才可以被驱逐。

下图展示一个Pod在调度周期内将可能会经历的过程。对于pending的Pod，调度器开始调度该Pod，等调度器为该Pod找到合适的调度节点后，Pod被allocated或者pipelined到节点上，如果此时，Pod所在的Job的gang约束得到满足，Pod被bind到这个节点上，否则，Pod仍然退回到pending的状态，等待下一个action或下一个调度周期的处理。

![](/images/posts/Linux-Kubernetes/volcano/6.png)

### Binpack调度

Binpack的调度策略是尽量的将容器调度到主要负载节点上，优先将集群下某些节点的资源占满，以提高资源使用率。同时，避免资源碎片化，在空闲的机器上为申请了更大资源请求的Pod预留足够的资源空间，使集群下空闲资源得到最大化的利用。

Binpack算法以插件的形式，注入到volcano-scheduler调度过程中，将会应用在Pod优选节点的阶段。Volcano-scheduler在计算binpack算法时，会考虑Pod请求的各种资源，并根据各种资源所配置的权重做平均。每种资源在节点分值计算过程中的权重并不一样，这取决于管理员为每种资源配置的权重值。同时不同的插件在计算节点分数时，也需要分配不同的权重，scheduler也为binpack插件设置了分数权重。binpack插件的资源和插件级别权重配置如下：

```sh
- plugins:    
- name: binpack    
arguments:
  # binpack插件权重
  binpack.weight: 10
  # cpu资源权重
  binpack.cpu: 5
  # memory资源权重
  binpack.memory: 1
  # gpu等其他资源类型
  binpack.resources: nvidia.com/gpu, example.com/foo  
  # gpu等其他资源权重配置  
  binpack.resources.nvidia.com/gpu: 2    
  binpack.resources.example.com/foo: 3
```

Binpack算法的流程如下图所示：

![](/images/posts/Linux-Kubernetes/volcano/7.jpg)

首先，遍历Pod请求中的所有资源类型，分别计算资源类型对应的节点分数。在为单一资源类型计算节点分数时，先计算节点上该资源的已经使用量和Pod对该资源的请求量的和与节点该资源的可分配资源的比值作为初始节点分数值，然后上述计算的值与系统配置的针对于该资源权重weight的乘积作为最终节点在这个资源类型上所得分数。当所有资源类型所对应的节点分数都计算完毕，将所有的资源类型对应的分数相加得到节点总分，并与Pod所申请的所有资源类型权重的总值相除得到对于这个Pod的调度，节点的分数值。最终将Node分值重新规划到0~10*binpackingweight之间。

选择含有两个节点的集群进行测试，其中节点资源规格均为4c8g，分别往集群下发两个MXNet job，Pod数量分别为16和24，每个Pod的资源请求为0.2c。查看Pod调度情况。测试结果显示，当Pod数量较少时，Pod全部调度到其中一个节点上，优先占满集群下某个节点的资源；当Pod数量较多时，该节点资源被占满，开始往其他的节点调度。

### Task-topology调度

Task-topology算法是一种根据Job内task之间亲和性和反亲和性配置计算task优先级和Node优先级的算法。通过在Job内配置task之间的亲和性和反亲和性策略，并使用task-topology算法，可优先将具有亲和性配置的task调度到同一个节点上，将具有反亲和性配置的Pod调度到不同的节点上。

同样是处理亲和性和反亲和性配置对Pod调度的影响，task-topology算法与Kubernetes默认调度器处理的不同点在于，Kubernetes默认调度器在调度Pod过程中，仅会检查Pod与现有集群下所有已经处于运行状态Pod的亲和性和反亲和性配置是否冲突或吻合，并不会考虑接下来可能会调度的Pod造成的影响；而task-topology将待调度的Pods作为一个整体进行亲和性和反亲和性考虑，在批量调度Pod的时候，考虑未调度Pod之间的亲和性和反亲和性影响，并通过优先级施加到Pod的调度进程中。

Task-topology对于提升深度学习计算场景下的计算效率非常重要。以TensorFlow计算为例，配置“ps”和“worker”之间的亲和性，以及“ps”与“ps”之间的反亲和性，task-topology算法，可使“ps”和“worker”尽量调度到同一台节点上，从而提升“ps”和“worker”之间进行网络和数据交互的效率，进而提升计算效率。

Volcano团队使用task-topology算法对TensorFlow任务进行性能测试。同时下发3组Tensorflow计算任务，每组TensorFlow任务包含2个“ps”和4个“worker”，对上述测试执行多次，并取平均完成时间，测试结果如下图所示。测试结果显示，当使用Kubernetes default-scheduler进行测试时，测试时间波动较大，而使用volcano调度器，测试时间相对稳定。最终测试平均时间显示，使用volcano调度器，其性能提升了33%。

![](/images/posts/Linux-Kubernetes/volcano/8.png)

[研究结果表明](https://i.cs.hku.hk/~cwu/papers/yhpeng-eurosys18.pdf)对于worker/parameter server的调度结果，存在如下图所示的多种组合，相比较三种调度结果，（c）场景所描述的调度结果，“ps”和“worker”之间网络互访速度更快，是最优的调度结果。Volcano配置使用task-topology调度算法可以实现TensorFlow计算任务的最优调度，提升计算效率。

![](/images/posts/Linux-Kubernetes/volcano/9.png)

### Fair Share调度

当集群资源不足，但运行了多个Job，并且每个Job下有不等数量的Pod等待被调度的时候，如果使用Kubernetes默认调度器，那么最终，具有更多Pod数量的Job将分得更多的集群资源。在这种情况下，volcano-scheduler提供算法支持不同的Job以fair-share的形式共享集群资源。

![](/images/posts/Linux-Kubernetes/volcano/10.png)

Fair-Share调度过程中使用Dominant Resource Fairness（DRF）的方法，DRF即主导资源公平性，volcano-scheduler观察每个Job请求的主导资源，并将其作为对集群资源使用的一种度量，根据Job的主导资源，计算Job的share值，在调度的过程中，具有较低share值的Job将具有更高的调度优先级。

Volcano支持多个维度的fair-share，包括queue与queue之间，namespace与namespace之间，queue内部Job与job之间。选择MXNet计算任务，分别使用Kubernetes default调度器和volcano调度器对比分析queue内部Job和Job之间的fair-share体现。投放两组MXNet计算任务，其中一组计算任务的Pod数量为300，一组计算任务的Pod数量为60，其中任何一组计算任务均可占满集群资源，查看最终调度成功的Pod数量。测试结果显示，使用volcano调度器，两组Job被调度的Pod数量相等，而使用Kubernetes默认调度器，Pod数量多的Job被调度的Pod数量也多，volcano调度器可以实现Job与Job之间的公平调度。

![](/images/posts/Linux-Kubernetes/volcano/11.jpg)


通过在namespace的ResourceQuota中配置“volcano.sh/namespace.weight”可以为namespace配置资源使用权重。调度过程中，具有更高权重的namespace下的Pod将具有更高的优先级获取集群资源。测试不同namespace之间的fair-share，集群下存在两个namespace：“vc-test-1”和“vc-test-2”。其中“vc-test-1” namespace的“volcano.sh/namespace.weight”值为3，“vc-test-2” namespace的“volcano.sh/namespace.weight”值为1。分别往“vc-test-1”和“vc-test-2” namespace下发含有60个Pod的Job。观察最终每个namespace下调度Pod的数量。测试结果显示，Job下所能调度的Pod数量与namespace的权重成正比。

![](/images/posts/Linux-Kubernetes/volcano/12.jpg)



### Gang调度

Gang调度策略是volcano-scheduler的核心调度算法之一，它满足了调度过程中的“All or nothing”的调度需求，避免Pod的任意调度导致集群资源的浪费。Gang调度遵循commit机制，在调度过程中，观察Job下的Pod已调度数量是否满足了最小运行数量，当Job的最小运行数量得到满足，为Job下的所有Pod执行调度动作，否则，跳过Job下Pod的调度。

Gang的约束不单单体现在调度阶段，也会影响Job下的Pod是否可以被驱逐。在计算Pod是否可以被驱逐时，如果驱逐后，Pod所在Job的gang约束被破坏，那么Pod不可被驱逐。

当集群下资源不足时，gang的调度策略对于集群资源的利用率的提升是非常明显的。

![](/images/posts/Linux-Kubernetes/volcano/13.png)


Volcano团队针对gang的调度策略做了一项测试。当集群资源不能同时满足两组2ps+4worker的TensorFlow作业并行计算的资源请求时，分别使用Kubernetes默认调度器和volcano调度器，验证并行下发一个上述TensorFlow作业，两个上述TensorFlow作业和五个上述TensorFlow作业，所消耗的时间。其结果显示，在资源充足的场景下，使用Kubernetes调度器和volcano调度器运行一组TensorFlow作业，作业运行时间一致。在集群资源不足的场景下，使用Kubernetes调度器和volcano调度器运行多组TensorFlow作业，使用Kubernetes调度器，会造成集群资源死锁，导致部分计算任务无法顺利完成，使用volcano调度器任务则可以顺利完成，volcano解决了Kubernetes默认调度器死锁问题。

测试结果如下图所示，其中case1 1 job with 2ps+4workder，case2 2jobs with 2ps+4workder case3 5jobswith 2ps+4worker。当集群资源不能满足多组计算任务同时运算时，如果多个计算任务下都有Pod在调度，那么会造成集群资源虽然被占用，但是TensorFlow作业并没有形成计算集群，而无法开始计算，造成集群资源的浪费。更有甚者，可能造成资源死锁，导致计算任务无法进行。

![](/images/posts/Linux-Kubernetes/volcano/14.png)

### 深度学习计算框架在Volcano上的运行

Volcano平台可以弥补Kubernetes在深度学习计算领域的不足。Volcano的批量创建批量调度计算任务为深度学习计算作业提供计算任务的自动化生命周期管理。Gang调度策略可以满足server、worker以及scheduler “all or nothing”的业务调度约束。使用queue管理划分集群资源，不仅可以保证集群资源使用的多租性，还能保证资源使用的弹性。

Volcano调度器支持插入多种调度算法，提供更适合深度学习计算任务运行模式的调度结果，提高计算任务的执行效率。在集群资源不足时，gang调度策略可以避免集群资源浪费和死锁，提升计算性能。另外，binpack和task-topology等调度算法的应用使计算任务的调度更贴合计算集群对节点资源和网络拓扑结构的要求而提升任务计算效率。

![](/images/posts/Linux-Kubernetes/volcano/15.jpg)

### Volcano与深度学习框架的结合

深度学习计算框架与volcano的结合非常方便，volcano “vcjob”支持定义插件，通过在“vcjob”中配置插件，可以实现计算框架与volcano计算平台的结合。目前，volcano已经实现了对几乎全部深度学习领域主流计算框架的支持，其中包括TensorFlow、MPI、MXNet以及国内第一款开源的深度学习框架PaddlePaddle。

![](/images/posts/Linux-Kubernetes/volcano/16.png)

### Volcano社区和贡献

Volcano在深度学习领域和大数据场景下的强势表现，赢得了很多公司的青睐，volcano的前景普遍看好。目前，已有十多家企业考虑使用volcano作为计算任务管理工具。详细的企业使用现状如下表所示：
![](/images/posts/Linux-Kubernetes/volcano/17.png)

### 总结与展望

自诞生以来，volcano已经成长为一个成熟、稳定、高性能的服务，无论是在技术交流上还是商业运行上，均取得了显著的成绩。在技术融合上，Volcano已经实现了与包括TensorFlow、MPI、MXNet、PaddlePaddle在内的诸多主流深度学习平台的结合。在企业交流上，volcano与“caicloud”、“Baidu”、 “Huawei Cloud”等多家企业接洽合作，其中有些企业已经将volcano运行到生产环境中。

不仅在深度学习计算领域，在大数据场景下，volcano的表现同样优异。Volcano已经完成了对Spark计算任务的支持，并且经过测试，使用volcano运行Spark任务，可使计算任务效率提升20%。另外，在Volcano上运行Flink作业已经处于测试中。

未来volcano将会支持更多的计算场景，并在计算领域提供更多的优化算法和工具。同时，也会有更多的公司和个人参与到volcano的发展中。

### 参考文献

1. [Kubernetes for Machine Learning Deep Learning &AI](https://mapr.com/ebook/kubernetes-for-machine-learning-deep-learning-and-ai/assets/Cloud_EB_Kubernetes_MLDL_SPONSOR.pdf)
2. [Optimus: An Efficient Dynamic Resource Scheduler for Deep Learning Clusters](https://i.cs.hku.hk/~cwu/papers/yhpeng-eurosys18.pdf)
3. [Job scheduling of kubeflow](https://www.kubeflow.org/docs/use-cases/job-scheduling/)
4. [Volcano introduction](https://github.com/volcano-sh/volcano/tree/master/example/huawei-connection)
5. [百度飞浆（PaddlePaddle）分布式训练在Volcano系统上的实践](https://www.infoq.cn/article/ut9TO5TpieF2b7KpGjjP)
6. [Volcano在Kubernetes中运行高性能实践](https://www.infoq.cn/article/KWS04BcEdpqhOwE*4Mci)
7. [Kubernetes增强型调度器Volcano算法分析](https://bbs.huaweicloud.com/blogs/118181?ticket=ST-110185-MehiCjezKur9zk1vBrFPRXwY-sso)
8. [华为云Volcano：让企业AI算力像火山一样爆发](https://zhuanlan.zhihu.com/p/77048090)
9. Volcano官网 https://volcano.sh/
10. Volcano社区 https://github.com/volcano-sh/volcano
11. [Namespace fair share of volcano](https://github.com/volcano-sh/volcano/blob/master/docs/design/fairshare.md)
12. [Queue of volcano](https://github.com/volcano-sh/volcano/tree/master/docs/design/queue)
13. [Reclaim action](https://github.com/volcano-sh/volcano/blob/master/docs/design/reclaim-action.md)
14. [Adopters of volcano](https://github.com/volcano-sh/volcano/blob/master/docs/community/adopters.md)

