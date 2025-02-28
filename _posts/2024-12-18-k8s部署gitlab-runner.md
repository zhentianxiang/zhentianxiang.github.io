---
layout: post
title: 2024-12-18-k8s部署gitlab-runner
date: 2024-12-18
tags: Devops

---

# 一、简单介绍

**GitLab-CI**

- GitLab CI/CD是GitLab的一部分，支持从计划到部署具有出色的用户体验。CI/CD是开源GitLab社区版和专有GitLab企业版的一部分。可以根据需要添加任意数量的计算节点，每个构建可以拆分为多个作业，这些作业可以在多台计算机上并行运行。
- GitLab-CI轻量级，不需要复杂的安装手段。配置简单，与gitlab可直接适配。实时构建日志十分清晰，UI交互体验很好。使用 YAML 进行配置，任何人都可以很方便的使用。GitLabCI 有助于DevOps人员，例如敏捷开发中，开发与运维是同一个人，最便捷的开发方式。

- 在大多数情况，构建项目都会占用大量的系统资源，如果让gitlab本身来运行构建任务的话，显然Gitlab的性能会大幅度下降。GitLab-CI最大的作用就是管理各个项目的构建状态。因此，运行构建任务这种浪费资源的事情交给一个独立的Gitlab Runner来做就会好很多，更重要的是Gitlab Runner 可以安装到不同的机器上，甚至是我们本机，这样完全就不会影响Gitlab本身了。
- 从GitLab8.0开始，GitLab-CI就已经集成在GitLab中，我们只需要在项目中添加一个.gitlab-ci.yaml文件，然后运行一个Runner，即可进行持续集成。

**GItLab Runner**

- Gitlab Runner是一个开源项目，用于运行您的作业并将结果发送给gitlab。它与Gitlab CI结合使用，gitlab ci是Gitlab随附的用于协调作用的开源持续集成服务。
- Gitlab Runner是用Go编写的，可以作为一个二进制文件运行，不需要特定于语言的要求
- 它皆在GNU/Linux，MacOS和Windows操作系统上运行。另外注意：如果要使用Docker，Gitlab Runner要求Docker 至少是v1.13.0版本才可以。

## 二、Helm 部署

### 1. 拉取 helm 包

```sh
$ helm repo add gitlab https://charts.gitlab.io
$ helm repo list
NAME  	URL
gitlab	https://charts.gitlab.io/
$ helm pull gitlab/gitlab-runner
$ tar xvf gitlab-runner-0.71.0.tgz 
```

### 2. 修改调整

```sh
$ vim values.yaml
image:
  registry: registry.gitlab.com
  image: gitlab-org/gitlab-runner
useTini: false
imagePullPolicy: IfNotPresent
livenessProbe: {}
readinessProbe: {}
replicas: 1
# gitlab 代码库地址
gitlabUrl: http://k8s-gitlab.localhost.com

# runner的token
runnerRegistrationToken: "glrt-7QQvoewUEWxxS9CXKymR"
unregisterRunners: true
terminationGracePeriodSeconds: 3600
concurrent: 10
shutdown_timeout: 0
checkInterval: 30
logLevel: info
sessionServer:
  enabled: false
  serviceType: LoadBalancer
rbac:
  create: true
  generatedServiceAccountName: ""
  rules:
    - resources: ["events"]
      verbs: ["list", "watch"]
    - resources: ["namespaces"]
      verbs: ["create", "delete"]
    - resources: ["pods"]
      verbs: ["create","delete","get"]
    - apiGroups: [""]
      resources: ["pods/attach","pods/exec"]
      verbs: ["get","create","patch","delete"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get","list"]
    - resources: ["secrets"]
      verbs: ["create","delete","get","update"]
    - resources: ["serviceaccounts"]
      verbs: ["get"]
    - resources: ["services"]
      verbs: ["create","get"]
  clusterWideAccess: true
  serviceAccountAnnotations: {}
  podSecurityPolicy:
    enabled: false
    resourceNames:
      - gitlab-runner
  imagePullSecrets: []
serviceAccount:
  create: true
  name: ""
  annotations: {}
  imagePullSecrets: []
metrics:
  enabled: false
  portName: metrics
  port: 9252
  serviceMonitor:
    enabled: false
service:
  enabled: false
  type: ClusterIP
runners:
  config: |
    [[runners]]
      output_limit = 512000
      [runners.kubernetes]
        namespace = "{{ .Release.Namespace }}"
        image= "ubuntu:22.04"
        privileged = true
        cpu_limit = "3"
        memory_limit = "5Gi"
        image_pull_secrets = ["harbor-registry-secret"]
      [runners.cache]
        Type = "s3"
        Path = "k8s-gitlab"
        Shared = true
        [runners.cache.s3]
          ServerAddress = "gitlab-runners-minio:9000"
          AccessKey = "QZsDibwKHtf73Ql2"
          SecretKey = "dr6KufmZ1bZ8JC06JYFOotA5gYdXI3Gh"
          BucketName = "gitlab-runners"
          BucketLocation = "k8s-gitlab"
          Insecure = true
        [[runners.kubernetes.volumes.host_path]]
            name = "docker"
            mount_path = "/var/run/docker.sock"
            host_path = "/var/run/docker.sock"
        [[runners.kubernetes.volumes.host_path]]
            name = "host-time"
            mount_path = "/etc/localtime"
            host_path = "/etc/localtime"
  configPath: ""
  # runner 的 tags
  tags: "k8s-gitlab"
  name: "kubernetes-runner"
  cache: {}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  privileged: false
  capabilities:
    drop: ["ALL"]
strategy: {}
podSecurityContext:
  runAsUser: 100
  fsGroup: 65533
resources:
  limits:
    memory: 8Gi
    cpu: 4
    ephemeral-storage: 4Gi
  requests:
    memory: 1Gi
    cpu: 500m
    ephemeral-storage: 800Mi
affinity: {}
topologySpreadConstraints: {}
runtimeClassName: ""
nodeSelector: {}
tolerations: []
extraEnv: {}
extraEnvFrom: {}
hostAliases: []
deploymentAnnotations: {}
deploymentLabels: {}
deploymentLifecycle: {}
podAnnotations: {}
podLabels: {}
priorityClassName: ""
secrets: []
configMaps: {}
volumeMounts: []
volumes: []
extraObjects: []
```

### 3. 解释配置

| 配置项                                   | 解释说明                                                     |
| ---------------------------------------- | ------------------------------------------------------------ |
| [[runners]]                              | Runner 的基本配置部分。                                      |
| output_limit                             | 设置单个作业（Job）日志输出的最大字节数。此处设置为 512,000 字节（约 500 KB）。 |
| [runners.kubernetes]                     | 与 Kubernetes 环境中的 GitLab Runner 配置相关。              |
| namespace                                | Runner 所在的 Kubernetes 命名空间，通常通过 Helm 动态替换为实际命名空间。 |
| image                                    | Runner 使用的 Docker 镜像，这里设置为 `ubuntu:22.04`，表示使用 Ubuntu 22.04 镜像。 |
| privileged                               | 是否允许 Runner 容器以特权模式运行，`true` 表示允许。通常用于需要 Docker-in-Docker 的场景。 |
| cpu_limit                                | 设置 Runner 容器使用的最大 CPU 配额，这里设置为 3 个 CPU 核心。 |
| memory_limit                             | 设置 Runner 容器使用的最大内存，单位为 GiB。此处设置为 5Gi。 |
| image_pull_secrets                       | 设置拉取 Docker 镜像所需的 Secret，这里指定了名为 `harbor-registry-secret` 的 Secret。 |
| [runners.cache]                          | 配置 GitLab Runner 使用的缓存后端，通常用于加速构建过程。    |
| Type                                     | 缓存存储类型，这里使用 `s3`，意味着使用 S3 存储服务（如 MinIO 或 AWS S3）作为缓存存储。 |
| Path                                     | 缓存存储路径，用于存储 Runner 的缓存数据。此处设置为 `gitlab-runner-cache-k8s-gitlab`。 |
| Shared                                   | 是否共享缓存。设置为 `true` 时，多个 Runner 可以共享缓存。   |
| [runners.cache.s3]                       | 配置与 S3 存储相关的具体设置。                               |
| ServerAddress                            | 设置 S3 存储服务的地址，这里设置为 `gitlab-runners-minio:9000`，指向 MinIO 实例。 |
| AccessKey                                | S3 存储服务的访问密钥，通常用于认证访问。此处为示例密钥。    |
| SecretKey                                | S3 存储服务的私密密钥，用于认证访问。                        |
| BucketName                               | 存储桶的名称，此处设置为 `gitlab-runners`。                  |
| BucketLocation                           | S3 存储桶的区域位置。设置为 `K8S-Runner`，指定存储区域。     |
| Insecure                                 | 是否使用不安全连接（如 HTTP）。设置为 `true` 表示不使用 HTTPS，`false` 则使用 HTTPS。 |
| [[runners.kubernetes.volumes.host_path]] | 配置 Kubernetes 中的卷挂载。                                 |
| name                                     | 卷的名称，用于区分不同的挂载卷。                             |
| mount_path                               | 容器内挂载点路径，这里设置为 `/var/run/docker.sock` 和 `/etc/localtime`。 |
| host_path                                | 宿主机路径，表示从宿主机挂载到容器的路径。                   |
| tags                                     | Runner 标签，用于在 GitLab CI/CD 配置中指定运行作业的 Runner。 |
| tags                                     | 设置 Runner 的标签，这里设置为 `k8s-gitlab`，用于作业匹配指定的 Runner。 |
| name                                     | Runner 名称，用于标识不同的 Runner。                         |

### 4. 部署

```sh
$ helm upgrade --install k8s-runner -n dev-ops ./ -f values.yaml
```

## 三、Yaml 方式部署

### 1. 配置 Token

```sh
$ vim gitlab-ci-token-secret.yaml

apiVersion: v1
kind: Secret
metadata:
  name: gitlab-ci-token
  namespace: dev-ops
  labels:
    app: gitlab-ci-runner
data:
  #  echo "glrt-7QQvoewUEWxxS9CXKymR" |base64
  GITLAB_CI_TOKEN: Z2xydC03UVF2b2V3VUVXeHhTOUNYS3ltUgo=
```

### 2. 配置注册和注销脚本

默认只有当 Pod 正常通过 Kubernetes（TERM 信号）终止时，才会触发 Runner 取消注册。 如果强制终止 Pod（SIGKILL 信号），Runner 将不会注销自身。必须手动清理这种**被杀死的** Runner 。

```sh
$ vim gitlab-runner-scripts-configmap.yaml

kind: ConfigMap
metadata:
  labels:
    app: gitlab-ci-runner
  name: gitlab-ci-runner-scripts
  namespace: dev-ops
apiVersion: v1
data:
  run.sh: |
    #!/bin/bash
    unregister() {
        kill %1
        echo "Unregistering runner ${RUNNER_NAME} ..."
        /usr/bin/gitlab-ci-multi-runner unregister -t "$(/usr/bin/gitlab-ci-multi-runner list 2>&1 | tail -n1 | awk '{print $4}' | cut -d'=' -f2)" -n ${RUNNER_NAME}
        exit $?
    }
    trap 'unregister' EXIT HUP INT QUIT PIPE TERM
    echo "Registering runner ${RUNNER_NAME} ..."
    /usr/bin/gitlab-ci-multi-runner register -r ${GITLAB_CI_TOKEN}
    sed -i 's/^concurrent.*/concurrent = '"${RUNNER_REQUEST_CONCURRENCY}"'/' /home/gitlab-runner/.gitlab-runner/config.toml
 
    cat >>/home/gitlab-runner/.gitlab-runner/config.toml <<EOF
            [[runners.kubernetes.volumes.host_path]]
              name = "docker"
              mount_path = "/var/run/docker.sock"
              read_only = true
              host_path = "/var/run/docker.sock"
            [[runners.kubernetes.volumes.host_path]]
              name = "host-time"
              mount_path = "/etc/localtime"
              read_only = true
              host_path = "/etc/localtime"
    EOF
 
    echo "Starting runner ${RUNNER_NAME} ..."
    /usr/bin/gitlab-ci-multi-runner run -n ${RUNNER_NAME} &
    wait
```

### 3. 配置 RBAC

```sh
$ vim gitlab-runner-rbac.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-ci
  namespace: dev-ops
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: gitlab-ci
  namespace: dev-ops
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: gitlab-ci
  namespace: dev-ops
subjects:
  - kind: ServiceAccount
    name: gitlab-ci
    namespace: dev-ops
roleRef:
  kind: Role
  name: gitlab-ci
  apiGroup: rbac.authorization.k8s.io
```

### 4. 配置 Runner

```sh
$ vim gitlab-runner-configmap.yaml

kind: ConfigMap
metadata:
  labels:
    app: gitlab-ci-runner
  name: gitlab-ci-runner
  namespace: dev-ops
apiVersion: v1
data:
  CACHE_TYPE: "s3"
  CACHE_SHARED: "true"
  CACHE_S3_SERVER_ADDRESS: "gitlab-runners-minio:9000"
  CACHE_S3_BUCKET_NAME: "gitlab-runners"
  CACHE_S3_ACCESS_KEY: "QZsDibwKHtf73Ql2"
  CACHE_S3_SECRET_KEY: "dr6KufmZ1bZ8JC06JYFOotA5gYdXI3Gh"
  CACHE_S3_INSECURE: "true"
  CACHE_PATH: "k8s-gitlab"
  CACHE_S3_BUCKET_LOCATION: "k8s-gitlab"
  REGISTER_NON_INTERACTIVE: "true"
  REGISTER_LOCKED: "false"
  METRICS_SERVER: "0.0.0.0:9100"
  CI_SERVER_URL: "http://k8s-gitlab.localhost.com/ci"
  RUNNER_REQUEST_CONCURRENCY: "4"
  RUNNER_EXECUTOR: "kubernetes"
  KUBERNETES_NAMESPACE: "dev-ops"
  KUBERNETES_PRIVILEGED: "true"
  KUBERNETES_CPU_LIMIT: "3"
  KUBERNETES_MEMORY_LIMIT: "4Gi"
  KUBERNETES_SERVICE_CPU_LIMIT: "3"
  KUBERNETES_SERVICE_MEMORY_LIMIT: "4Gi"
  KUBERNETES_HELPER_CPU_LIMIT: "500m"
  KUBERNETES_HELPER_MEMORY_LIMIT: "500Mi"
  KUBERNETES_PULL_POLICY: "if-not-present"
  KUBERNETES_TERMINATIONGRACEPERIODSECONDS: "10"
  KUBERNETES_POLL_INTERVAL: "5"
  KUBERNETES_POLL_TIMEOUT: "360"
  RUNNER_TAG_LIST: "k8s-gitlab"
  RUNNER_NAME: "k8s-runner"
  RUNNER_OUTPUT_LIMIT: "5120000"
```

更多环境变量设置请进入容器后执行：`gitlab-ci-multi-runner register --help` 命令查看

### 5. Runner 服务

```sh
$ vim gitlab-runner-statefulset.yaml

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: gitlab-ci-runner
  namespace: dev-ops
  labels:
    app: gitlab-ci-runner
spec:
  selector:
    matchLabels:
      app: gitlab-ci-runner      
  updateStrategy:
    type: RollingUpdate
  replicas: 2
  serviceName: gitlab-ci-runner
  template:
    metadata:
      labels:
        app: gitlab-ci-runner
    spec:
      serviceAccountName: gitlab-ci
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        supplementalGroups: [999]
      containers:
      - image: gitlab/gitlab-runner:latest
        name: gitlab-ci-runner
        command:
        - /scripts/run.sh
        envFrom:
        - configMapRef:
            name: gitlab-ci-runner
        - secretRef:
            name: gitlab-ci-token
        ports:
        - containerPort: 9100
          name: http-metrics
          protocol: TCP
        volumeMounts:
        - name: gitlab-ci-runner-scripts
          mountPath: "/scripts"
          readOnly: true
      volumes:
      - name: gitlab-ci-runner-scripts
        projected:
          sources:
          - configMap:
              name: gitlab-ci-runner-scripts
              items:
              - key: run.sh
                path: run.sh
                mode: 0755
      restartPolicy: Always
```

## 三、gitlab-ci 文件

### 1. maven 项目用法


```yaml
stages:
  - package
  - docker_build
  - deploy_k8s

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=.cache/.m2/repository"  # Maven 本地仓库
  DOCKER_AUTH_CONFIG: '{"auths":{"harbor.meta42.indc.vnet.com": {"auth": "emhlbnRpYW54aWFuZzpUaWFuMTgzMzI4MjUzMDku"}}}'

mvn_build_job:
  #image: harbor.meta42.indc.vnet.com/sameersbn/maven-aliyun-mirror:3.6.2-jdk-14
  image: harbor.meta42.indc.vnet.com/tools/maven:3.5.2
  stage: package
  tags:
    - k8s-gitlab
  script:
    - mkdir -p .cache/.m2/repository # maven 依赖
    - mvn clean package -Dmaven.test.skip=true
    - JAR_NAME=$(ls ruoyi-admin/target/*.jar | grep -v "original" | head -n 1)  # 动态获取 JAR 文件名
    - mkdir -p .cache/jar  # 确保缓存目录存在
    - cp $JAR_NAME .cache/jar/  # 把打好的 jar 包缓存到这个目录里面，然后推送到 minio
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/.m2/repository  # Maven 依赖缓存路径
      - .cache/jar  # 缓存 JAR 文件，
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: on_success

docker_build_job:
  image: harbor.meta42.indc.vnet.com/sameersbn/docker:latest
  stage: docker_build
  tags:
    - k8s-gitlab
  script:
    - mkdir -p .cache/  # 确保缓存目录存在
    - JAR_NAME=$(ls .cache/jar/*.jar | head -n 1)  # 从缓存中动态获取 JAR 文件名
    - mkdir -pv target
    - cp $JAR_NAME target/  # 复制 JAR 文件
    - mkdir ~/.docker/
    - echo $DOCKER_AUTH_CONFIG > ~/.docker/config.json
    - cat ~/.docker/config.json
    - TAG_NAME="${CI_COMMIT_REF_NAME}-$(date +%Y%m%d%H%M)-${CI_COMMIT_SHORT_SHA}-${CI_PIPELINE_ID}"
    - echo $TAG_NAME > .cache/tag_name.txt  # 将 TAG_NAME 写入文件
    - docker build -t harbor.meta42.indc.vnet.com/library/ruoyi-admin:$TAG_NAME .
    - docker push harbor.meta42.indc.vnet.com/library/ruoyi-admin:$TAG_NAME
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/jar  # 确保 JAR 文件在构建阶段可用
      - .cache/tag_name.txt     # 拉取镜像tag文件
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: on_success

deploy_k8s_job:
  image: harbor.meta42.indc.vnet.com/sameersbn/kubectl:v1.23.0
  stage: deploy_k8s
  tags:
    - k8s-gitlab
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/tag_name.txt
  script:
    - mkdir -pv ~/.kube/
    - mkdir -pv .cache
    - ls -lh
    - cat .cache/tag_name.txt  # 从缓存中读取变量
    - TAG_NAME=$(cat .cache/tag_name.txt)
    - |
      if [[ "$CI_COMMIT_BRANCH" =~ ^test-.* ]]; then
        echo '部署服务到测试环境'
        echo $test_kube_config | base64 -d > ~/.kube/config
        echo '172.16.246.30 apiserver.cluster.local' >> /etc/hosts
        sed -i "s/TAG_NAME/$TAG_NAME/g" k8s/deployment.yaml
        sed -i "s/deploy_env/test/g" k8s/
        cat ~/.kube/config
        cat /etc/hosts
        cat k8s/deployment.yaml
        kubectl apply -f k8s/deployment.yaml
      elif [[ '$CI_COMMIT_BRANCH == "main"' ]]; then
        echo '部署服务到生产环境'
        echo $prod_kube_config | base64 -d > ~/.kube/config
        echo '172.16.246.150 apiserver.cluster.local' >> /etc/hosts
        sed -i "s/TAG_NAME/$TAG_NAME/g" k8s/deployment.yaml
        sed -i "s/deploy_env/prod/g" k8s/deployment.yaml
        cat ~/.kube/config
        cat /etc/hosts
        cat k8s/deployment.yaml
        kubectl apply -f k8s/
      fi

  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'  # 只在 test-xxxx 分支上触发
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: manual  # 手动触发 main 部署
````

```dockerfile
FROM harbor.meta42.indc.vnet.com/tools/jdk-8u421-skywalking-java-agent-9.3.0:latest

ARG PORT

ARG JAVA_OPT

ARG Platform

ARG ApplicationName

ARG Skywalking

MAINTAINER SunHarvey

ENV PORT=8080

ENV USER=root

ENV APP_HOME=/home/$USER/apps

ENV JAR_FILE=app.jar

ENV JAVA_OPT=${JAVA_OPT}

ENV Platform=${Platform}

ENV Skywalking=${Skywalking}

ENV ApplicationName=${ApplicationName}

COPY target/*.jar ${APP_HOME}/${JAR_FILE}

COPY start.sh ${APP_HOME}/start.sh

WORKDIR ${APP_HOME}

CMD ["sh", "-c", "/bin/sh $APP_HOME/start.sh"]
```

```sh
#!/bin/sh
# 启动 Java 应用
java -Dfile.encoding=UTF-8 \
     ${JAVA_OPT} \
     -jar ${APP_HOME}/${JAR_FILE}
```

### 2. nodejs 前端用法

```yaml
image: harbor.meta42.indc.vnet.com/sameersbn/docker:latest

stages:
  - package
  - docker_build
  - deploy_k8s

variables:
  DOCKER_AUTH_CONFIG: '{"auths":{"harbor.meta42.indc.vnet.com": {"auth": "emhlbnRpYW54aWFuZzpUaWFuMTgzMzI4MjUzMDku"}}}'

node_build_job:
  image: harbor.meta42.indc.vnet.com/library/node:14  # 使用 Node.js 官方镜像
  stage: package
  tags:
    - TEST-K8S-CLUSTER
  script:
    - npm install --registry=https://registry.npmmirror.com  # 使用淘宝镜像安装依赖
    - npm run build:prod
    - mkdir -p .cache  # 确保缓存目录存在
    - cp -r node_modules .cache/node_modules  # 将 node_modules 缓存
    - cp -r dist .cache/dist   # 将生成的前端文件拷贝到缓存
    - ls -lh
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/node_modules  # 缓存 cache 目录
      - .cache/dist

  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: on_success

docker_build_job:
  image: harbor.meta42.indc.vnet.com/sameersbn/docker:latest
  stage: docker_build
  tags:
    - TEST-K8S-CLUSTER
  script:
    - mkdir -p .cache  # 创建缓存目录
    - cp -r .cache/dist dist  # 从缓存中获取前端文件 dist
    - mkdir ~/.docker/
    - echo $DOCKER_AUTH_CONFIG > ~/.docker/config.json
    - cat ~/.docker/config.json
    - TAG_NAME="${CI_COMMIT_REF_NAME}-$(date +%Y%m%d%H%M)-${CI_COMMIT_SHORT_SHA}-${CI_PIPELINE_ID}"
    - echo $TAG_NAME > .cache/tag_name.txt  # 将 TAG_NAME 写入文件
    - docker build -t harbor.meta42.indc.vnet.com/library/ruoyi-ui:$TAG_NAME .
    - docker push harbor.meta42.indc.vnet.com/library/ruoyi-ui:$TAG_NAME
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/dist    # 拉取build完的前端缓存目录
      - .cache/tag_name.txt     # 拉取镜像tag文件

  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: on_success

deploy_k8s_job:
  image: harbor.meta42.indc.vnet.com/sameersbn/kubectl:v1.23.0
  stage: deploy_k8s
  tags:
    - k8s-gitlab
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .cache/tag_name.txt
  script:
    - mkdir -pv ~/.kube/
    - mkdir -pv .cache
    - ls -lh
    - cat .cache/tag_name.txt  # 从缓存中读取变量
    - TAG_NAME=$(cat .cache/tag_name.txt)
    - |
      if [[ "$CI_COMMIT_BRANCH" =~ ^test-.* ]]; then
        echo '部署服务到测试环境'
        echo $test_kube_config | base64 -d > ~/.kube/config
        echo '172.16.246.30 apiserver.cluster.local' >> /etc/hosts
        sed -i "s/TAG_NAME/$TAG_NAME/g" k8s/deployment.yaml
        sed -i "s/deploy_env/test/g" k8s/deployment.yaml
        cat ~/.kube/config
        cat /etc/hosts
        cat k8s/deployment.yaml
        kubectl apply -f k8s/
      elif [[ '$CI_COMMIT_BRANCH == "main"' ]]; then
        echo '部署服务到生产环境'
        echo $prod_kube_config | base64 -d > ~/.kube/config
        echo '172.16.246.150 apiserver.cluster.local' >> /etc/hosts
        sed -i "s/TAG_NAME/$TAG_NAME/g" k8s/deployment.yaml
        sed -i "s/deploy_env/prod/g" k8s/deployment.yaml
        cat ~/.kube/config
        cat /etc/hosts
        cat k8s/deployment.yaml
        kubectl apply -f k8s/
      fi

  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^test-.*/'  # 只在 test-xxxx 分支上触发
      when: on_success
    - if: '$CI_COMMIT_BRANCH == "main"'  # 只在 main 分支上触发
      when: manual  # 手动触发 main 部署
```

```dockerfile
FROM harbor.meta42.indc.vnet.com/library/nginx:latest


# 将构建好的 dist 目录复制到 Nginx 的默认静态文件目录
COPY dist /usr/share/nginx/html

# 如果有自定义的 nginx 配置文件，可以复制到容器中
# COPY nginx.conf /etc/nginx/nginx.conf

# 暴露 Nginx 使用的端口，默认是 80
EXPOSE 80

# 启动 Nginx 服务
CMD ["nginx", "-g", "daemon off;"]
```

## 四、上手测试

### 1. gitlab 新建变量

首先你要新建用户组，然后在用户组这一级别进行配置

因为流水线部署到 k8s 是通过客户端证书通信的，所以要准备好相应的工作

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/1.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/2.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/3.png)

做完之后你要把相应的用户加入到用户组中，这样的话他们就具备使用该变量的权限了

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/4.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/5.png)

### 2. 配置远程仓库

首先你要先准备新建一个空的项目，登陆到你的gitlab账号，进入到你的组中，新建项目

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/6.png)

然后本地开发工具添加远端仓库

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/7.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/8.png)

然后新建一个 test-xxx 的分支，推送自己的项目代码到仓库中

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/9.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/10.png)

### 3. 检查流水线构建

不出意外的话你就能在 gitlab 页面中看到流水线信息了

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/11.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/12.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/13.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/14.png)

### 4. 分支合并生产环境部署

由于我的流水线中判断多个分支，当前流水线任务在哪个分支中运行，就执行哪个分支的动作，即所以，当分支合并到 main 分支中，就会出发 main 分支的流水线，服务自然也就部署到了生产环境中。

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/15.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/16.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/17.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/18.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/19.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/20.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/21.png)

![](/images/posts/Linux-Kubernetes/k8s部署gitlab-runner/22.png)