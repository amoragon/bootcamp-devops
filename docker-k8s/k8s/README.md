# Kubernetes

<a name=indice></a>
## Índice

* [Introducción](#intro)
* [Manifiesto de Namespace]()
* [Manifiesto de Secrets](#secrets)

### MariaDB

* [Manifiesto de ConfigMap](#mariadb-configmap)
* [Manifiesto de StatefulSet](#mariadb-statefulset)
* [Manifiesto Headless Service](#mariadb-headless)

### Aplicación Spring Boot

* [Manifiesto de ConfigMap](#spring-app-configmap)
* [Manifiesto Deployment](#spring-app-deployment)
* [Manifiesto ClusterIP Service](#spring-app-clusterip)
* [Manifiesto Ingress](#spring-app-ingress)
    * [Integración con cert-manager](#cert-manager)
* [Eliminación de recursos/objetos de kubernetes](#desinstalar)

<a name=intro></a>
## Introducción

Para la ejecución de la aplicación, comentada en la sección de docker, en un cluster de kubernetes hay dos partes bien diferenciadas:

* base de datos 
* aplicación Spring Boot

Cada una de ella tendrá una serie de manifiestos asociados de manera independiente, a excepción de uno de ellos. Vamos a ir describiendo cada uno de estos manifiestos, de manera que al final tengamos la aplicación funcionando en el cluster.

__Disclaimer:__ 

* Se asume que el usuario que va a seguir las instrucciones tiene establecido el alias `k=kubectl` para la línea de comandos.
* El directorio de ejecución desde el que se lanzan los comandos es `k8s`.
* Se hace uso de un cluster de Kubernetes de Google Cloud. Será necesario:  
    * Conectar con nuestro cluster usando una instrucción similar a: `gcloud container clusters get-credentials <nombre-de-cluster> --region <region> --project <id-de-proyecto-gcloud>`
    * Ser administrador del cluster. Explicado [aquí](https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke)

<a name=namespace></a>
## Manifiesto de Namespace - `namespace.yml`

Todos los objetos creados estarán bajo el namespace `keepcoding`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: keepcoding
```

Creamos el namespace en primer lugar.

```
k apply -f namespace.yml
```

<a name=secrets></a>
## Manifiesto de Secrets - `secrets.yml`

El manifiesto `secrets.yml` es usado tanto por la base de datos MariaDB, como por la aplicación Spring Boot.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secrets
  namespace: keepcoding
type: Opaque
data:
  mariadb-user: ...
  mariadb-password: ...
  mariadb-root-password: ...
```
Este fichero consta de tres valores que se construyen:

```
# Valor para la propiedad mariadb-user
$ echo -n ... | base64
...

# Valor para la propiedad mariadb-user
$ echo -n ... | base64
...

# Valor para la propiedad mariadb-user
$ echo -n ... | base64
...

```
Si quisiéramos otros valores simplemente tenemos que cambiar los valores y volverlos a codificar en base64.

A continuación ejecutamos en la línea de comandos:

```
k apply -f secrets.yml
```
para que cargar el objeto `secrets` en el cluster de kubernetes.

<a name=mariadb-configmap></a>
## Manifiesto ConfigMap - `mariadb-configmap.yml`

En este manifiesto simplemente guardamos el nombre de la base de datos que se va a crear para ser usada por la aplicación.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mariadb-configmap
  namespace: keepcoding
data:
  MARIADB_DATABASE: "spring_app"
```

Creamos el objeto en el cluster con el siguiente comando:

```
k apply -f mariadb-configmap.yml
```

<a name=mariadb-statefulset></a>
## Manifiesto StatefulSet - `mariadb-statefulset.yml`

Dado que deseamos ejecutar un motor de base de datos, necesitamos controlarlo con un WorkLoad de tipo StatefulSet, dado que deseamos conservar el estado de nuestra base de datos. El manifiesto es el siguiente:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mariadb
  namespace: keepcoding
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mariadb
  serviceName: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                labelSelector:
                  matchLabels:
                    app: spring-app
              topologyKey: "kubernetes.io/hostname"
            weight: 1
      containers:
      - image: mariadb
        name: mariadb
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mariadb-data
          mountPath: /var/lib/mysql
        env:
          - name: MARIADB_USER
            valueFrom:
              secretKeyRef:
                name: secrets
                key: mariadb-user
          - name: MARIADB_ROOT_PASSWORD
            valueFrom:
              secretKeyRef:
                name: secrets
                key: mariadb-root-password
          - name: MARIADB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: secrets
                key: mariadb-password
          - name: MARIADB_DATABASE
            valueFrom:
              configMapKeyRef:
                name: mariadb-configmap
                key: MARIADB_DATABASE

  volumeClaimTemplates:
  - metadata:
      name: mariadb-data
      namespace: keepcoding
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "standard"
      resources:
        requests:
          storage: 1Gi
```

En este manifiesto destacamos algunos de elementos:

* Se establece afinidad __"preferred"__ por aquellos pods que sean de la aplicación spring-app (app=spring-app). De manera que se encuentren juntos en el mismo nodo.
* indicamos el puerto del contenedor (3306) donde está escuchando la base de datos
* los valores de las variables de entorno: `MARIADB_USER`, `MARIADB_ROOT_PASSWORD` y `MARIADB_PASSWORD` se leerán desde el objeto de Secrets declarado al principio. 
* el valor de la variable de entorno `MARIADB_DATABASE` tomará el valor del configmap declarado anteriormente.
* finalmente, damos de alta un volumen, que se montará en `/var/lib/mysql`, y dicho volumen se gestionará a través de un __PersistenVolumenClaim__, que pide 1Gb de disco de tipo standard.

Aplicamos este manifiesto ejecutando:

```
k apply -f mariadb-statefulset.yml
```

<a name=mariadb-headless></a>
## Manifiesto Headless Service - `mariadb-headless.yml`

Para que el StatefulSet anterior pueda ser accedido, requiere de un Servicio de tipo __Headless__. Lo declaramos a continuación:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: keepcoding
  labels:
    app: mariadb
spec:
  ports:
  - port: 3306
    name: mariadb
  clusterIP: None
  selector:
    app: mariadb
```

El servicio de tipo Headless se indica con: `clusterIP: None`. Aplicamos este manifiesto con: 

```
k apply -f mariadb-headless.yml
```

<a name=spring-app-configmap></a>
## Manifiesto ConfigMap - `spring-app-configmap.yml`

En este manifiesto de ConfigMap establecemos la configuración no sensible de la aplicación, es decir, mantenemos fuera el usuario y contraseña.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: spring-app-configmap
  namespace: keepcoding
data:
  DB_HOST: "mariadb"
  DB_PORT: "3306"
  DB_SCHEMA: "spring_app"
```

Aplicamos este manifiesto con:

```
k apply -f spring-app-configmap.yml
```


<a name=spring-app-deployment></a>
## Manifiesto Deployment - `spring-app-deployment.yml`

Para la ejecución de la aplicación declaramos un objeto de tipo Deployment, ya que el estado de nuestra aplicación se mantendrá en la base de datos.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
  namespace: keepcoding
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      name: spring-app
      labels:
        app: spring-app
    spec:
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                labelSelector:
                  matchLabels:
                    app: mariadb
              topologyKey: "kubernetes.io/hostname"
                #weight: 1
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: spring-app
              topologyKey: "kubernetes.io/hostname"
      containers:
      - image: amoragon/spring-app
        name: spring-app
        ports:
        - containerPort: 8080
        env:
          - name: DB_USER
            valueFrom:
              secretKeyRef:
                name: secrets
                key: mariadb-user
          - name: DB_USER_PASSWD
            valueFrom:
              secretKeyRef:
                name: secrets
                key: mariadb-password
          - name: DB_HOST
            valueFrom:
              configMapKeyRef:
                name: spring-app-configmap
                key: DB_HOST
          - name: DB_PORT
            valueFrom:
              configMapKeyRef:
                name: spring-app-configmap
                key: DB_PORT
          - name: DB_SCHEMA
            valueFrom:
              configMapKeyRef:
                name: spring-app-configmap
                key: DB_SCHEMA
```
Puntos a destacar: 

* al igual que en el manifiesto `mariadb-stateful.yml` realizamos recíproca la afinidad por pods de la base de datos (app=mariadb), de manera que compartan nodo.
* fijamos una antiafinidad `preferred` para que los pods de spring-app permanezcan en host separados, y en caso de que se necesite seguir escalando, al tratarse de una antiafinidad "blanda". Con la configuración actual, se ejecutarán 3 pods de spring-app (uno en cada nodo) y 2 pods de mariadb. De manera spring-app y mariadb compartan nodo en dos ocasiones, y en un tercer nodo sólo habrá un pod de aplicación.
* se hará uso de la imagen `amoragon/spring-app` que se construyó y subió a Docker Hub, en la sección de docker.
* indicamos el puerto del contenedor (8080) donde está escuchando la aplicación.
* los valores de las variables de entorno: `DB_USER` y `DB_USER_PASSWD` se leerán desde el objeto de Secrets declarado al principio. 
* el valor de las variables de entorno `DB_HOST`, `DB_PORT` y `DB_SCHEMA` tomarán el valor del configmap declarado anteriormente.

Aplicamos este manifiesto con:

```
k apply -f spring-app-deployment.yml
```

<a name=spring-app-clusterip></a>
## Manifiesto ClusterIP - `spring-app-clusterip.yml`

Para poder hacer uso de la aplicación controlada por el deployment anterior, haremos uso de un servicio de tipo ClusterIP, como se puede ver a continuación.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-app
  namespace: keepcoding
spec:
  type: ClusterIP
  selector:
    app: spring-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```
El servicio se consumirá en el puerto `80`, mientras que la aplicación escucha en el puerto `8080`.

Aplicamos este manifiesto con:

```
k apply -f spring-app-clusterip.yml
```

<a name=spring-app-hpa></a>
## Manifiesto HPA - `spring-app-hpa.yml`

Configuramos un autoescalado automático de manera que cuando pase del 70% de CPU aumenten el número de pods que dan servicio de la aplicación `spring-app`. 

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: spring-app-hpa
  namespace: keepcoding
spec:
  maxReplicas: 10
  minReplicas: 1
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: spring-app
  targetCPUUtilizationPercentage: 70
```

<a name=spring-app-ingress></a>
## Manifiesto Ingress - `spring-app-ingress.yml`

### Instalación Ingress Controller 

Por último, para poder acceder a nuestra aplicación haremos uso de un `Ingress Controller`, el cual hace la labor de proxy inverso. Para esto será necesario que lo instalemos en nuestro cluster kubernetes. Para esto basta con que ejecutemos:

```
k apply -f ingress-controller-v1.1.1.yaml
```
El fichero ingress-controller-v1.1.1.yaml lo hemos descargado de la [web oficial](https://kubernetes.github.io/ingress-nginx/deploy/). Podemos instalarlo sin descargar:

```
k apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml
```

Como resultado de la aplicar el fichero del `Ingress Controller`, se crea un `Namespace ingress-nginx`, donde se encuentran todos los objetos creados. Podemos ver todos los objetos ejecutando:

```
$ k get all -n ingress-nginx
NAME                                            READY   STATUS      RESTARTS   AGE
pod/ingress-nginx-admission-create-f5jsd        0/1     Completed   0          3m5s
pod/ingress-nginx-admission-patch-p5n97         0/1     Completed   0          3m5s
pod/ingress-nginx-controller-54d8b558d4-zctrb   1/1     Running     0          3m6s

NAME                                         TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.56.1.144   34.140.183.235   80:32761/TCP,443:31098/TCP   3m6s
service/ingress-nginx-controller-admission   ClusterIP      10.56.3.139   <none>           443/TCP                      3m6s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           3m6s

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-54d8b558d4   1         1         1       3m6s

NAME                                       COMPLETIONS   DURATION   AGE
job.batch/ingress-nginx-admission-create   1/1           2s         3m5s
job.batch/ingress-nginx-admission-patch    1/1           2s         3m5s
```

Podemos ver el servicio `ingress-nginx-controller` que es de tipo `LoadBalancer`, que será el que acepte las conexiones a nuestro servicio. Vemos que la ip externa es: `34.140.183.235`

### Host de servicio nip.io

A continuación es necesario configurar el objeto `Ingress`, para indicar el host desde el cual se accede desde Internet (nombre DNS) a nuestro servicio. Para esto haremos uso del servicio de resolución de DNS nip.io. 

De manera que si indicamos como host: `practica.34-140-183-235.nip.io`, dicho servicio resolverá a la ip indicada en el nombre. Más detalles en la web de [nip.io](https://nip.io/).

Por tanto, modificamos el fichero `spring-app-ingress.yml`, para que el campo de host tenga este valor.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-spring-host
  namespace: keepcoding
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /demo/all
spec:
  rules:
  - host: practica.34-140-183-235.nip.io
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: spring-app
            port:
              number: 80
```

Aplicamos este manifiesto con:

```
k apply -f spring-app-ingress.yml
```

También es necesario indicar en el objeto ingress la anotación `nginx.ingress.kubernetes.io/rewrite-target: /demo/all`, dado que la aplicación spring, responde al contexto `/demo/all`.

Así pues, accediendo al host `practica.34-140-183-235.nip.io`, veremos los datos almacenados en la base de datos. 

<a name=anadir-datos></a>
### Añadir datos a la base de datos

En caso de que no tengamos datos, podemos ejecutar un contenedor para poder hacer peticiones curl e insertarlos. Para esto en primer lugar consultamos la ip del pod que sirve a aplicación con y veremos una salida similar a:

```
$ k get pod -o=wide
NAME                          READY   STATUS    RESTARTS   AGE     IP            NODE                                       NOMINATED NODE   READINESS GATES
mariadb-0                     1/1     Running   0          32m     10.52.2.121   gke-micluster-default-pool-2cd76489-q8ls   <none>           <none>
spring-app-56f85f6848-p5xtd   1/1     Running   0          29m     10.52.0.112   gke-micluster-default-pool-005a2ae5-6gfb   <none>           <none>
```
Nos quedamos con la ip del contenedor que su nombre empieza por `spring-app-`, que en este caso es 10.52.0.112

Lazanmos el contenedor desde el que vamos a insertar datos de la siguiente manera:
```
k run curl-test -it --image=alpine/curl --rm -- sh
```

Procedemos a realizar peticiones para insertar datos de la siguiente manera:

```
$ curl 10.52.0.112:8080/demo/add -d name=john.doe -d email=john.doe@myemail.com
```

Una vez hayamos hecho esto, podemos volver al navegador y volver a consultar la dirección `http://practica.34-140-183-235.nip.io`, y veremos los datos introducidos en la base de datos. 

<a name="cert-manager"></a>
### Integración con cert-manager

Si deseamos que nuestra navegación sea segura usando __HTTPS__, en lugar de __HTTP__, será necesario disponer de un certifado https, para automatizar esta tarea necesitaremos: instalar cert-manager, crear un objeto ClusterIssuer y modificar nuestro manifiesto de `Ingress`.

Instalamos cert-manager en el cluster:

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
```

Esto creará un namespace `cert-manager` donde se alojarán una serie de objetos.

Creamos un objeto de tipo `ClusterIssuer`. Deberemos establecer una cuenta de correo electrónico a la que tengamos acceso. Crearemos uno que apunte al entorno de staging.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: keepcoding
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: antonio.moragon@gmail.com
    #server: https://acme-v02.api.letsencrypt.org/directory
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: keepcoding-staging-issuer-account-very-secret-key
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          class: nginx
```

Lo instalamos con:

```
k apply -f letsencrypt-issuer.yml
```
Comprobamos que se ha instalado correctamente:

```
k get clusterissuers.cert-manager.io
NAME          READY   AGE
letsencrypt   True    28s
```

Será necesario modificar el fichero `spring-app-ingress.yml` de la siguiente manera:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-spring-host
  namespace: keepcoding
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /demo/all
    cert-manager.io/cluster-issuer: letsencrypt-staging
spec:
  tls:
  - hosts:
    - practica.34-140-183-235.nip.io
    secretName: nginx-ingress-ssl-cert
  rules:
  - host: practica.34-140-183-235.nip.io
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: spring-app
            port:
              number: 80
```

Se añade la anotación `cert-manager.io/cluster-issuger`, además de la sección `spec.tls`. Aplicamos el fichero de ingress. 

```
k apply -f spring-app.ingress.yml
```

Si ahora accedemos a la dirección `https://practica.34-140-183-235.nip.io` (notar el https), podremos acceder haciendo uso del certificado generado gracias a `Let's Encrypt`.

<a name="desinstalar"></a>
## Eliminación de recursos/objetos de kubernetes

Una vez probada la aplicación si deseamos eliminar todos los recursos creados, bastará con ejecutar lo siguiente:

```
k delete -f namespace.yml
k delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml
k delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
```
Con esto eliminaremos todos los recursos de nuestra aplicación, todo lo relacionado con el `Ingress Controller` y con el `cert-manager`.


[Volver al índice](#indice)

[Volver al índice principal](../README.md)