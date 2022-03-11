# Helm Charts

<a name=indice></a>
## Índice

* [Introducción](#intro)
* [Fichero values.yml](#values)
    * [Descripción de los valores](#descripcion-valores)
* [Creación de un nueva Release](#nueva-release)  
    * [Instalación de Ingress Controller](#ingress-controller)
    * [Host de servicio nip.io](#host-nio-io)
    * [Instalación de la release del chart](#instalacion-release)
* [Desinstalación de la Release](#desinstalar)

<a name=intro></a>
## Introducción

En el directorio `/charts`, se encuentra el chart de Helm que se ha desarrollado: `spring-app`. En las siguientes secciones se describirán los valores de configuración del chart, que se encuentran en el fichero  `values.yaml`. 
Posteriormente se darán las instrucciones para generar una release del chart.

__Disclaimer__: 

* Se asume que el usuario tiene establecido el alias `k=kubectl` para la línea de comandos.
* El directorio de ejecución desde el que se lanzan los comandos es `charts`.
* Se hace uso de un cluster de Kubernetes de Google Cloud. Será necesario:  
    * Conectar con nuestro cluster usando una instrucción similar a: `gcloud container clusters get-credentials <nombre-de-cluster> --region <region> --project <id-de-proyecto-gcloud>`
    * Ser administrador del cluster. Explicado [aquí](https://kubernetes.github.io/ingress-nginx/deploy/#gce-gke)

<a name=values></a>
## Fichero values.yml

En estes fichero (`spring-app/values.yml`) se contemplan todos los posibles valores a configurar del chart para poder instalar una release del mismo. A continuación un ejemplo de todos los posibles valores:

```yaml
db:
  name: spring-db
  user:
  password:
  rootPassword:
  servicePort: 3306

app:
  host: demo.34-76-208-229.nip.io
  port: 80

replicas:
  db: 1
  app: 1

volumeStorageSize: 1Gi

affinity:
  app_db:
    enabled: true
  app_app:
    enabled: false
    
hpa:
  maxReplicas: 10
  minReplicas: 1
  cpuPercentage: 70

cert_manager:
  enabled: true
  ingress:
    secretName: nginx-ingress-ssl-cert
  cluster_issuer:
    email: antonio.moragon@gmail.com
    env: staging 
    secretKey: very-secret-key
```
<a name="descripcion-valores"></a>
### Descripción de los valores

* __`db.name`__: nombre de la base de datos que se creará para almacenar los datos. 

* __`db.user`__: nombre de usuario de la base de datos para poder consultarla. Este valor debe establecerse en base64, para ello si queremos indicar el valor `sprin_user`, deberemos obtener el valor ejecutando: `echo -n spring_user | base64` .  
Se permite un valor vacío, de manera que se creará un valor aleatorio de 8 caracteres. Se usarán como posibles caracteres [a-zA-Z], este valor aleatorio también quedará codificado en base64.

* __`db.password`__: valor de la contraseña del usuario de base de datos. Este valor también debe establecerse en base64. Procederemos del mismo modo para codificar que en el anterior caso. También se permite un valor vacío, en este caso se creará un valor aleatorio de 15 caracteres alfanumérico [0-9a-zA-Z], quedará codificado en base64.

* __`db.rootPassword`__: valor de la contraseña del usuario root de la base de datos. Se comporta igual que `db.password`.

* __`db.servicePort`__: puerto donde escucha la base de datos. Este valor se usará en los templates `mariadb-headless.yml` y `spring-app-configmap.yml`. Por ejemplo: `3306`.

---

* __`app.host`__: nombre del host donde quedará expuesta la aplicación. Por ejemplo: `demo.34-76-208-229.nip.io`.

* __`app.port`__: puerto desde el que se sirve la aplicación al exterior. Por ejemplo: `80`.

---

* __`replicas.db`__: número de replicas que queremos de la base de datos.

* __`replicas.app`__: número de replicas que servirán la aplicación.

---

* __`volumeStorageSize`__: tamaño del volumen que se utilizará en el PersistenVolumeClaim para compartir por las replicas de la base de datos. Por ejemplo, `1Gi`. [Aquí](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-memory) se pueden consultar los posibles valores de unidades de memoria de kubernetes.

---

* __`affinity.app_db.enabled`__: True o false para indicar si existe afinidad o no entre los pods de la aplicación y la base de datos.
* __`affinity.app_app.enabled`__: True o false para indicar si existe afinidad o no entre los pods de la aplicación.

---

* __`hpa.maxReplicas`__: Número máximo de pods a los que puede escalar el autoscaler.
* __`hpa.minReplicas`__: Número mínimo de pods a los que puede escalar el autoscaler.
* __`hpa.cpuPercentage`__: Porcentaje de CPU a partir del cual el autoscaler aumentará el número de replicas. 

---

* __`cert_manager.enabled`__: Habilitamos o no la integración con cert-manager.
* __`cert_manager.ingress.secretName`__: valor de la propiedad `spec.tls.hosts.secretName` del objeto Ingress. En caso de que se deje en blanco se generará un valor alfanumérico aleatorio de 20 caracteres. 
* __`cert_manager.clusterIssuer.email`__: email que se utilizará dentro del objeto `ClusterIssuer`, para la emisión del certificado por parte de Let's Encrypt.
* __`cert_manager.clusterIssuer.env`__: Esta propiedad puede tomar los valores: `prod`, `staging`, `both`
* __`cert_manager.clusterIssuer.secretKey`__: Clave secreta que se utilizará por el emisor para almacenar la clave privada de la cuenta.

<a name="nueva-release"></a>
## Creación de un nueva Release

Antes de crear una nueva release es necesario instalar un `Ingress Controller` y disponer de un host del servicio nip.io. En caso de que se habilite el `cert-manager` también será necesario instalarlo previamente. A continuación se detallan los pasos a seguir.

<a name="ingress-controller"></a>
### Instalación de Ingress Controller

Descargamos el fichero `ingress-controller-v1.1.1.yaml` de la [web oficial](https://kubernetes.github.io/ingress-nginx/deploy/) y ejecutamos:

```
k apply -f ingress-controller-v1.1.1.yaml
```
o simplemente 

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml
```
Una vez instalado el `Ingress Controller` necesitaremos averiguar la ip del balanceador generado, para esto podemos ejecutar:

```
k get svc -n ingress-nginx
```

En uno de los dos servicios se nos indicará la ip del balanceador, esta ip será la que usemos para el siguiente punto. 

<a name="host-nio-io"></a>
### Host de servicio nip.io

Con la ip obtenida, por ejemplo `34.76.208.229`, podemos generar un nombre de host como, por ejemplo, el siguiente: `keepcoding.34-76-208-229.nip.io`. Con esto conseguimos obtener la ip del balanceador a través de un nombre DNS. Más detalles en la web de [nip.io](https://nip.io/).

### Instalación de cert-manager

Instalamos cert-manager en el cluster:

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
```

<a name="instalacion-release"></a>
### Instalación de la release del chart

Una vez hemos realizado los dos pasos anteriores crearemos un fichero `yaml`, donde especificaremos todos los valores para personalizar. Por ejemplo, creamos el fichero `myvalues.yml` con los siguientes valores:

```yaml
db:
  name: spring-db
  # c3ByaW5nLXVzZXI= equivale a spring-user en base64
  user: c3ByaW5nLXVzZXI=
  # c3ByaW5nLXVzZXItcGFzc3dvcmQ= equivale a spring-user-password en base64
  password: c3ByaW5nLXVzZXItcGFzc3dvcmQ=
  rootPassword:
  servicePort: 3306

app:
  host: keepcoding.34-76-208-229.nip.io
  port: 80

replicas:
  db: 1
  app: 1

volumeStorageSize: 1Gi

affinity:
  app_db:
    enabled: true
  app_app:
    enabled: false

hpa:
  maxReplicas: 5
  minReplicas: 2
  cpuPercentage: 50
  
cert_manager:
  enabled: true
  ingress:
    secretName: nginx-ingress-ssl-cert
  cluster_issuer:
    email: antonio.moragon@gmail.com
    env: prod 
    secretKey: very-secret-key
```
Siguiendo las indicaciones previas de las propiedades del fichero `values.yml` hemos configurado las propiedades `db.user` y `db.password`, mientras que hemos dejado sin fijar `db.rootPassword`. 

Para resolver dudas sobre la generación de los valores en base64 consultar la sección de [descripción de valores](#descripcion-valores).

Por otro lado, hemos indicado que existe afinidad entre los pods de la aplicación y la base de datos, y que no existe entre pods que ejecuten la aplicación.

Establecemos un mínimo de 2 y un máximo de 5 replicas, para el deployment de la aplicación. Indicando que se activará a partir de que se supere un 50% de uso de CPU.

Una vez disponemos del fichero bastará con ejecutar el comando:

```
helm install -f myvalues.yml keepcoding spring-app/
```

Ahora podremos consultar la URL [http://keepcoding.34-76-208-229.nip.io](http://keepcoding.34-76-208-229.nip.io) para ver los datos almacenados en la base de datos.

Si no existen datos que consultar, podemos añadirlos tal y como se indicó en las instrucciones de la sección de kubernetes [aquí](../k8s/README.md#anadir-datos).

__Nota:__ En la sección de kubernetes se añadió un namespace `keepcoding` donde guardar todos los objetos. Para poder crear los objetos en un namespace bastaría con lanzar el siguiente comando:

```
helm install -f myvalues.yml --namespace keepcoding --create-namespace keepcoding spring-app/
```
con lo que no sería necesario modificar las plantillas, ni añadir un fichero `yaml` que cree dicho namespace.

<a name=desinstalar></a>
## Desinstalación de la Release

Para desinstalar la release bastará con ejecutar:

```
helm uninstall keepcoding
```
Recordar que los PersistentVolumeClaims no se eliminan, junto con los PersistenVolumes, por lo que será necesario eliminarlos expresamente con la siguiente instrucción:

```
k delete pvc --all
```

o también podemos eliminar directamente el namespace `keepcoding` y se eliminarán también junto con el namespace.

```
k delete namespaces keepcoding
```

A continuación, desinstalamos `cert-manager` con:

```
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
```

También debemos desinstalar el `Ingress Controller` para evitar cualquier facturación por parte de GCE, ya que se hace uso de una ip pública. Para desinstalar basta con ejecutar lo siguiente:

```
k delete -f ingress-controller-v1.1.1.yaml
```

Si no nos hemos descargado el fichero `ingress-controller-v1.1.1.yaml` también podemos hacer:

```
k delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/cloud/deploy.yaml
```

[Volver al índice](#indice)

[Volver al índice principal](../README.md)
