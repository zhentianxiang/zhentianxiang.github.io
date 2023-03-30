---
layout: post
title: Linux-Kubernetes-29-部署spinnaker其它组件
date: 2021-05-16
tags: 实战-Kubernetes
---

## 4 部署spinnaker其它组件

### 4.1 spinnaker之front50部署

```sh
[root@host0-200 clouddriver]# mkdir -pv /data/k8s-yaml/armory/front50 && cd /data/k8s-yaml/armory/front50
mkdir: 已创建目录 "/data/k8s-yaml/armory/front50"
[root@host0-200 front50]# pwd
/data/k8s-yaml/armory/front50
```

#### 4.1.1 准备镜像

```sh
[root@host0-200 front50]# docker pull armory/spinnaker-front50-slim:release-1.8.x-93febf2
release-1.8.x-93febf2: Pulling from armory/spinnaker-front50-slim
4fe2ade4980c: Already exists 
6fc58a8d4ae4: Pull complete 
d3e6d7e9702a: Pull complete 
622e7480b6bf: Pull complete 
9d3ccf3d3d25: Pull complete 
8861884c807a: Pull complete 
Digest: sha256:92309ff0c8d676b7dafbeb09bb78babbba669dffd7ed8878438f91d53cfb02f6
Status: Downloaded newer image for armory/spinnaker-front50-slim:release-1.8.x-93febf2
docker.io/armory/spinnaker-front50-slim:release-1.8.x-93febf2
[root@host0-200 front50]# docker tag armory/spinnaker-front50-slim:release-1.8.x-93febf2 harbor.od.com/armory/front50:v1.8.x
[root@host0-200 front50]# docker push harbor.od.com/armory/front50:v1.8.x
The push refers to repository [harbor.od.com/armory/front50]
dfaf560918e4: Pushed 
44956a013f38: Pushed 
78bd58e6921a: Pushed 
12c374f8270a: Pushed 
0c3170905795: Pushed 
df64d3292fd6: Mounted from public/traefik 
v1.8.x: digest: sha256:b2da7cfd07d831f0399a253541453fbf9a374fb9de9ecfcc5bf2a2fd97839bba size: 1579
```

#### 4.1.2 准备资源清单

```sh
[root@host0-200 front50]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-front50
  name: armory-front50
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-front50
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-front50"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"front50"'
      labels:
        app: armory-front50
    spec:
      containers:
      - name: armory-front50
        image: harbor.od.com/armory/front50:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh && cd /home/spinnaker/config
          && /opt/front50/bin/front50
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: -javaagent:/opt/front50/lib/jamm-0.2.5.jar -Xmx1000M
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 600
          periodSeconds: 3
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 5
          successThreshold: 8
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /home/spinnaker/.aws
          name: credentials
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - name: credentials
        secret:
          defaultMode: 420
          secretName: credentials
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```sh
[root@host0-200 front50]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-front50
  namespace: armory
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: armory-front50
```

#### 4.1.3 应用资源清单

```sh
[root@host0-200 front50]# kubectl apply -f ./dp.yaml 
deployment.apps/armory-front50 created
[root@host0-200 front50]# kubectl apply -f ./svc.yaml 
service/armory-front50 created
```

#### 4.1.4 验证

```sh
[root@host0-21 opt]# kubectl exec -it -n armory minio-db454548b-jvk7d -- bash
[root@minio-db454548b-jvk7d /]# curl armory-front50:8080/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.2 spinnaker之orca部署

```sh
[root@host0-200 front50]# mkdir -pv /data/k8s-yaml/armory/orca && cd  /data/k8s-yaml/armory/orca
mkdir: 已创建目录 "/data/k8s-yaml/armory/orca"
```

#### 4.2.1 准备docker镜像

```sh
[root@host0-200 orca]# docker pull docker.io/armory/spinnaker-orca-slim:release-1.8.x-de4ab55
release-1.8.x-de4ab55: Pulling from armory/spinnaker-orca-slim
4fe2ade4980c: Already exists 
6fc58a8d4ae4: Already exists 
d3e6d7e9702a: Already exists 
6c70af887bc7: Pull complete 
c4b6e637d6e8: Pull complete 
da01b2afaa26: Pull complete 
Digest: sha256:aeb403299da62e26c018d5ff3ce7ba20a6a92d9dc0c48fa16edef37e20316bb3
Status: Downloaded newer image for armory/spinnaker-orca-slim:release-1.8.x-de4ab55
docker.io/armory/spinnaker-orca-slim:release-1.8.x-de4ab55
[root@host0-200 orca]# docker tag armory/spinnaker-orca-slim:release-1.8.x-de4ab55 harbor.od.com/armory/orca:v1.8.x
[root@host0-200 orca]# docker push harbor.od.com/armory/orca:v1.8.x
The push refers to repository [harbor.od.com/armory/orca]
fc691dbda20f: Pushed 
df3bd4d73885: Pushed 
c5165988c0bd: Pushed 
12c374f8270a: Mounted from armory/front50 
0c3170905795: Mounted from armory/front50 
df64d3292fd6: Mounted from armory/front50 
v1.8.x: digest: sha256:4be2da614968e0722d766c67d30e16701b93718950736785a1cd1664572ccd32 size: 1578
```

#### 4.2.2 准备资源清单

```sh
[root@host0-200 orca]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-orca
  name: armory-orca
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-orca
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-orca"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"orca"'
      labels:
        app: armory-orca
    spec:
      containers:
      - name: armory-orca
        image: harbor.od.com/armory/orca:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh && cd /home/spinnaker/config
          && /opt/orca/bin/orca
        ports:
        - containerPort: 8083
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: -Xmx1000M
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /health
            port: 8083
            scheme: HTTP
          initialDelaySeconds: 600
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8083
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 3
          successThreshold: 5
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```sh
[root@host0-200 orca]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-orca
  namespace: armory
spec:
  ports:
  - port: 8083
    protocol: TCP
    targetPort: 8083
  selector:
    app: armory-orca
```

#### 4.2.3 应用资源配置清单

```sh
[root@host0-200 orca]# kubectl apply -f dp.yaml 
deployment.apps/armory-orca created
[root@host0-200 orca]# kubectl apply -f svc.yaml 
service/armory-orca created
```

#### 4.2.4 检查

```sh
[root@minio-db454548b-jvk7d /]# curl armory-orca:8083/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.3 spinnaker之echo部署

```sh
[root@host0-200 orca]# mkdir -pv /data/k8s-yaml/armory/echo
mkdir: 已创建目录 "/data/k8s-yaml/armory/echo"
[root@host0-200 orca]# cd /data/k8s-yaml/armory/echo/
```

#### 4.3.1 准备docker镜像

```sh
[root@host0-200 echo]# docker pull docker.io/armory/echo-armory:c36d576-release-1.8.x-617c567
c36d576-release-1.8.x-617c567: Pulling from armory/echo-armory
12a7970a6783: Pull complete 
38a1c0aaa6fd: Pull complete 
fb7693893388: Pull complete 
c29ed2a5f1b6: Pull complete 
69c3c33e23e9: Pull complete 
5662e03596af: Pull complete 
Digest: sha256:33f6d25aa536d245bc1181a9d6f42eceb8ce59c9daa954fa9e4a64095acf8356
Status: Downloaded newer image for armory/echo-armory:c36d576-release-1.8.x-617c567
docker.io/armory/echo-armory:c36d576-release-1.8.x-617c567
[root@host0-200 echo]# docker tag armory/echo-armory:c36d576-release-1.8.x-617c567 harbor.od.com/armory/echo:v1.8.x
[root@host0-200 echo]# docker push harbor.od.com/armory/echo:v1.8.x
The push refers to repository [harbor.od.com/armory/echo]
1800ebd4bcda: Pushed 
e1f2ca83d794: Pushed 
7f4fe63acda3: Pushed 
20dd87a4c2ab: Pushed 
78075328e0da: Pushed 
9f8566ee5135: Pushed 
v1.8.x: digest: sha256:3bf7315b4804e8b055b5e9c0d87450c99700dc15c368d6b7815e8df50ff7e426 size: 1579
```

#### 4.3.2 准备资源配置清单

```sh
[root@host0-200 echo]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-echo
  name: armory-echo
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-echo
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-echo"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"echo"'
      labels:
        app: armory-echo
    spec:
      containers:
      - name: armory-echo
        image: harbor.od.com/armory/echo:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh && cd /home/spinnaker/config
          && /opt/echo/bin/echo
        ports:
        - containerPort: 8089
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: -javaagent:/opt/echo/lib/jamm-0.2.5.jar -Xmx1000M
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8089
            scheme: HTTP
          initialDelaySeconds: 600
          periodSeconds: 3
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8089
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 3
          successThreshold: 5
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```sh
[root@host0-200 echo]# vim svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: armory-echo
  namespace: armory
spec:
  ports:
  - port: 8089
    protocol: TCP
    targetPort: 8089
  selector:
    app: armory-echo
```

#### 4.3.3 应用资源配置清单

```sh
[root@host0-200 echo]# kubectl apply -f dp.yaml 
deployment.apps/armory-echo created
[root@host0-200 echo]# kubectl apply -f svc.yaml 
service/armory-echo created
```

#### 4.3.4 检查

```sh
[root@minio-db454548b-jvk7d /]# curl armory-echo:8089/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.4 spinnaker之igor部署

```sh
[root@host0-200 echo]# mkdir -pv /data/k8s-yaml/armory/igor && cd /data/k8s-yaml/armory/igor
mkdir: 已创建目录 "/data/k8s-yaml/armory/igor"
```

#### 4.4.1 准备docker镜像

```sh
[root@host0-200 igor]# docker pull docker.io/armory/spinnaker-igor-slim:release-1.8-x-new-install-healthy-ae2b329
release-1.8-x-new-install-healthy-ae2b329: Pulling from armory/spinnaker-igor-slim
ff3a5c916c92: Pull complete 
a8906544047d: Pull complete 
590b87a38029: Pull complete 
246dc9ee5476: Pull complete 
04efcaf9f873: Pull complete 
da906be06326: Pull complete 
Digest: sha256:2a487385908647f24ffa6cd11071ad571bec717008b7f16bc470ba754a7ad258
Status: Downloaded newer image for armory/spinnaker-igor-slim:release-1.8-x-new-install-healthy-ae2b329
docker.io/armory/spinnaker-igor-slim:release-1.8-x-new-install-healthy-ae2b329
[root@host0-200 igor]# 
[root@host0-200 igor]# docker tag armory/spinnaker-igor-slim:release-1.8-x-new-install-healthy-ae2b329  harbor.od.com/armory/igor:v1.8.x
[root@host0-200 igor]# docker push harbor.od.com/armory/igor:v1.8.x
The push refers to repository [harbor.od.com/armory/igor]
86e21a74a10c: Pushed 
f18424cc1043: Pushed 
aa52633c7e64: Pushed 
8fcf61ed46a1: Pushed 
a8cc3712c14a: Pushed 
cd7100a72410: Pushed 
v1.8.x: digest: sha256:2a487385908647f24ffa6cd11071ad571bec717008b7f16bc470ba754a7ad258 size: 1578
```

#### 4.4.2 准备资源配置清单

```sh
[root@host0-200 igor]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-igor
  name: armory-igor
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-igor
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-igor"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"igor"'
      labels:
        app: armory-igor
    spec:
      containers:
      - name: armory-igor
        image: harbor.od.com/armory/igor:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh && cd /home/spinnaker/config
          && /opt/igor/bin/igor
        ports:
        - containerPort: 8088
          protocol: TCP
        env:
        - name: IGOR_PORT_MAPPING
          value: -8088:8088
        - name: JAVA_OPTS
          value: -Xmx1000M
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8088
            scheme: HTTP
          initialDelaySeconds: 600
          periodSeconds: 3
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /health
            port: 8088
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 5
          successThreshold: 5
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      securityContext:
        runAsUser: 0
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```
[root@host0-200 igor]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-igor
  namespace: armory
spec:
  ports:
  - port: 8088
    protocol: TCP
    targetPort: 8088
  selector:
    app: armory-igor
```

#### 4.4.3 应用资源配置清单 

```sh
[root@host0-200 igor]# kubectl apply -f dp.yaml 
deployment.apps/armory-igor created
[root@host0-200 igor]# kubectl apply -f svc.yaml 
service/armory-igor created
```

#### 4.4.4  检查

```sh
[root@minio-db454548b-jvk7d /]# curl armory-igor:8088/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.5 spinnaker之gate部署

```sh
[root@host0-200 igor]# mkdir -pv /data/k8s-yaml/armory/gate && cd /data/k8s-yaml/armory/gate
mkdir: 已创建目录 "/data/k8s-yaml/armory/gate"
```

#### 4.5.1 准备docker镜像

```sh
[root@host0-200 gate]# docker pull docker.io/armory/gate-armory:dfafe73-release-1.8.x-5d505ca
dfafe73-release-1.8.x-5d505ca: Pulling from armory/gate-armory
12a7970a6783: Already exists 
38a1c0aaa6fd: Already exists 
fb7693893388: Already exists 
f6e81adf2fc6: Pull complete 
d81889909516: Pull complete 
804d515d9470: Pull complete 
Digest: sha256:e3ea88c29023bce211a1b0772cc6cb631f3db45c81a4c0394c4fc9999a417c1f
Status: Downloaded newer image for armory/gate-armory:dfafe73-release-1.8.x-5d505ca
docker.io/armory/gate-armory:dfafe73-release-1.8.x-5d505ca
[root@host0-200 gate]# docker tag armory/gate-armory:dfafe73-release-1.8.x-5d505ca harbor.od.com/armory/gate:v1.8.x
[root@host0-200 gate]# docker push harbor.od.com/armory/gate:v1.8.x
The push refers to repository [harbor.od.com/armory/gate]
6d2409165e36: Pushed 
25907606e564: Pushed 
f75150ad7e46: Pushed 
20dd87a4c2ab: Mounted from armory/echo 
78075328e0da: Mounted from armory/echo 
9f8566ee5135: Mounted from armory/echo 
v1.8.x: digest: sha256:545ae2225a124015c7608bb65e0b404148911d946fdd512b0feeb41e59f1c4e1 size: 1577
```

#### 4.5.2 准备资源配置清单

```sh
[root@host0-200 gate]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-gate
  name: armory-gate
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-gate
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-gate"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"gate"'
      labels:
        app: armory-gate
    spec:
      containers:
      - name: armory-gate
        image: harbor.od.com/armory/gate:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh gate && cd /home/spinnaker/config
          && /opt/gate/bin/gate
        ports:
        - containerPort: 8084
          name: gate-port
          protocol: TCP
        - containerPort: 8085
          name: gate-api-port
          protocol: TCP
        env:
        - name: GATE_PORT_MAPPING
          value: -8084:8084
        - name: GATE_API_PORT_MAPPING
          value: -8085:8085
        - name: JAVA_OPTS
          value: -Xmx1000M
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - wget -O - http://localhost:8084/health || wget -O - https://localhost:8084/health
          failureThreshold: 5
          initialDelaySeconds: 600
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - wget -O - http://localhost:8084/health?checkDownstreamServices=true&downstreamServices=true
              || wget -O - https://localhost:8084/health?checkDownstreamServices=true&downstreamServices=true
          failureThreshold: 3
          initialDelaySeconds: 180
          periodSeconds: 5
          successThreshold: 10
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      securityContext:
        runAsUser: 0
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```sh
[root@host0-200 gate]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-gate
  namespace: armory
spec:
  ports:
  - name: gate-port
    port: 8084
    protocol: TCP
    targetPort: 8084
  - name: gate-api-port
    port: 8085
    protocol: TCP
    targetPort: 8085
  selector:
    app: armory-gate
```

#### 4.5.3 应用资源配置清单

```sh
[root@host0-200 gate]# kubectl apply -f dp.yaml 
deployment.apps/armory-gate created
[root@host0-200 gate]# kubectl apply -f svc.yaml 
service/armory-gate created
```

#### 4.5.4 检查

```
[root@minio-db454548b-jvk7d /]# curl armory-gate:8084/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.6 spinnaker之deck部署

```
[root@host0-200 gate]# mkdir -pv /data/k8s-yaml/armory/deck
mkdir: 已创建目录 "/data/k8s-yaml/armory/deck"
[root@host0-200 gate]# cd /data/k8s-yaml/armory/deck/
```

#### 4.6.1  准备docker镜像

```sh
[root@host0-200 deck]# docker pull docker.io/armory/deck-armory:d4bf0cf-release-1.8.x-0a33f94
d4bf0cf-release-1.8.x-0a33f94: Pulling from armory/deck-armory
cf0a75889057: Pull complete 
c8de9902faf0: Pull complete 
a3c0f7711c5e: Pull complete 
e6391432e12c: Pull complete 
624ce029a17f: Pull complete 
c7b18362c9ae: Pull complete 
7b9914ffa0d3: Pull complete 
f212d95417f6: Pull complete 
e7de6608a940: Pull complete 
532b97612378: Pull complete 
b15dbf201531: Pull complete 
ca28775a6e92: Pull complete 
Digest: sha256:ad85eb8e1ada327ab0b98471d10ed2a4e5eada3c154a2f17b6b23a089c74839f
Status: Downloaded newer image for armory/deck-armory:d4bf0cf-release-1.8.x-0a33f94
docker.io/armory/deck-armory:d4bf0cf-release-1.8.x-0a33f94
[root@host0-200 deck]# docker tag armory/deck-armory:d4bf0cf-release-1.8.x-0a33f94  harbor.od.com/armory/deck:v1.8.x
[root@host0-200 deck]# docker  push harbor.od.com/armory/deck:v1.8.x
The push refers to repository [harbor.od.com/armory/deck]
7a83eddefe6b: Pushed 
28a427580c04: Pushed 
0371824b6e1b: Pushed 
1338fd1b3201: Pushed 
14e3d0d46256: Pushed 
c426a599a7c7: Pushed 
b9e54f6f12bd: Pushed 
776d5289b76e: Pushed 
0fb55a72eab2: Pushed 
a30ab2bcda94: Pushed 
99840408c5ea: Pushed 
a8e78858b03b: Pushed 
v1.8.x: digest: sha256:ce5d700a727cff8cdd415de7454dbd6fc7b88251e4ecac599a022b2b95740c21 size: 2822
```

#### 4.6.2 准备资源配置清单

```sh
[root@host0-200 deck]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-deck
  name: armory-deck
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-deck
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-deck"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"deck"'
      labels:
        app: armory-deck
    spec:
      containers:
      - name: armory-deck
        image: harbor.od.com/armory/deck:v1.8.x
        imagePullPolicy: IfNotPresent
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh && /entrypoint.sh
        ports:
        - containerPort: 9000
          protocol: TCP
        envFrom:
        - configMapRef:
            name: init-env
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 3
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 5
          httpGet:
            path: /
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 3
          successThreshold: 5
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /etc/podinfo
          name: podinfo
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /opt/spinnaker/config/custom
          name: custom-config
      imagePullSecrets:
      - name: harbor
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
      - downwardAPI:
          defaultMode: 420
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.labels
            path: labels
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.annotations
            path: annotations
        name: podinfo
```

```sh
[root@host0-200 deck]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-deck
  namespace: armory
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 9000
  selector:
    app: armory-deck
```

#### 4.6.3 应用资源配置清单

```sh
[root@host0-200 deck]# kubectl apply -f dp.yaml 
deployment.apps/armory-deck created
[root@host0-200 deck]# kubectl apply -f svc.yaml 
service/armory-deck created
```

#### 4.6.4 检查

```sh
[root@minio-db454548b-jvk7d /]# curl armory-igor:8088/health
{"status":"UP"}[root@minio-db454548b-jvk7d /]# 
```

### 4.7 spinnaker之nginx部署

```sh
[root@host0-200 deck]# mkdir -pv /data/k8s-yaml/armory/nginx
mkdir: 已创建目录 "/data/k8s-yaml/armory/nginx"
[root@host0-200 deck]# cd /data/k8s-yaml/armory/nginx
```

#### 4.7.1 准备docker镜像 

```sh
[root@host0-200 nginx]# docker pull nginx:1.12.2
1.12.2: Pulling from library/nginx
f2aa67a397c4: Pull complete 
e3eaf3d87fe0: Pull complete 
38cb13c1e4c9: Pull complete 
Digest: sha256:72daaf46f11cc753c4eab981cbf869919bd1fee3d2170a2adeac12400f494728
Status: Downloaded newer image for nginx:1.12.2
docker.io/library/nginx:1.12.2
[root@host0-200 nginx]# docker tag nginx:1.12.2 harbor.od.com/armory/nginx:v1.12.2
[root@host0-200 nginx]# docker push harbor.od.com/armory/nginx:v1.12.2
The push refers to repository [harbor.od.com/armory/nginx]
4258832b2570: Pushed 
683a28d1d7fd: Pushed 
d626a8ad97a1: Pushed 
v1.12.2: digest: sha256:09e210fe1e7f54647344d278a8d0dee8a4f59f275b72280e8b5a7c18c560057f size: 948
```

#### 4.7.2 准备资源配置清单

```sh
[root@host0-200 nginx]# vim dp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: armory-nginx
  name: armory-nginx
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: armory-nginx
  template:
    metadata:
      annotations:
        artifact.spinnaker.io/location: '"armory"'
        artifact.spinnaker.io/name: '"armory-nginx"'
        artifact.spinnaker.io/type: '"kubernetes/deployment"'
        moniker.spinnaker.io/application: '"armory"'
        moniker.spinnaker.io/cluster: '"nginx"'
      labels:
        app: armory-nginx
    spec:
      containers:
      - name: armory-nginx
        image: harbor.od.com/armory/nginx:v1.12.2
        imagePullPolicy: Always
        command:
        - bash
        - -c
        args:
        - bash /opt/spinnaker/config/default/fetch.sh nginx && nginx -g 'daemon off;'
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        - containerPort: 443
          name: https
          protocol: TCP
        - containerPort: 8085
          name: api
          protocol: TCP
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 80
            scheme: HTTP
          initialDelaySeconds: 180
          periodSeconds: 3
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 80
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 3
          successThreshold: 5
          timeoutSeconds: 1
        volumeMounts:
        - mountPath: /opt/spinnaker/config/default
          name: default-config
        - mountPath: /etc/nginx/conf.d
          name: custom-config
      imagePullSecrets:
      - name: harbor
      volumes:
      - configMap:
          defaultMode: 420
          name: custom-config
        name: custom-config
      - configMap:
          defaultMode: 420
          name: default-config
        name: default-config
```

```sh
[root@host0-200 nginx]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: armory-nginx
  namespace: armory
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  - name: api
    port: 8085
    protocol: TCP
    targetPort: 8085
  selector:
    app: armory-nginx
```

```sh
[root@host0-200 nginx]# vim ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: spinnaker
    web: spinnaker.od.com
  name: spinnaker-route
  namespace: armory
spec:
  rules:
  - host: spinnaker.od.com
    http:
      paths:
      - backend:
          serviceName: armory-nginx
          servicePort: 80
```

#### 4.7.3 应用资源配置清单

```sh
[root@host0-200 nginx]# kubectl apply -f dp.yaml 
deployment.apps/armory-nginx created
[root@host0-200 nginx]# kubectl apply -f svc.yaml 
service/armory-nginx created
[root@host0-200 nginx]# kubectl apply -f ingress.yaml 
ingress.extensions/spinnaker-route created
```

#### 4.7.4 配置named解析

```sh
[root@host0-200 nginx]# vim /var/named/od.com.zone
spinnaker          A    10.0.0.10
[root@host0-200 nginx]# systemctl restart named
```

#### 4.7.5 完结

浏览器访问：http://spinnaker.od.com/
