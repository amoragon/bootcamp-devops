# Docker y Docker Compose

<a name=indice></a>
## Índice

* [Aplicación usada](#aplicacion)
    * [Funcionamiento](#funcionamiento)
    * [Requisitos de la aplicación](#requisitos)
    * [Opciones de configuración de la aplicación](#configuracion)
* [Dockerfile para la construcción del contenedor](#dockerfile)
* [Construcción de la imagen y subida a Docker Hub](#construccion-imagen)
* [Prueba de funcionamiento en local - contenedores](#standalone)
* [Prueba de funcionamiento en local - docker compose](#compose)

<a name="aplicacion"></a>
## Aplicación usada

La aplicación utilizada para la práctica la he obtenido de la siguiente [web](https://spring.io/guides/gs/accessing-data-mysql/). Se trata de una aplicación __Spring Boot__ que accede a una base de datos MySQL. 

<a name="funcionamiento"></a>
### Funcionamiento

El comportamiento de la aplicación es el siguiente:

* Haciendo una petición del tipo como la siguiente `$ curl host:8080/demo/add -d name=First -d email=someemail@someemailprovider.com` se guardan los datos en la base de datos.
* Accediendo a http://__HOST:PUERTO__//demo/all, se obtienen todas las instancias de la base de datos.

<a name="requisitos"></a>
### Requisitos de la aplicación

Para poner en funcionamiento la aplicación necesitamos las siguientes herramientas:

* Java 8.
* Gradle o Maven. 
* Base de datos MySQL.

__Nota:__ 

* he optado por el uso de __Maven__ como herramienta para la compilación y, 
* por una base de datos _MariaDB_, debido a que las imágenes de _MySQL_ no estaban disponibles para arquitectura ARM (uso Mac con __Apple Silicon__).

<a name="configuracion"></a>
### Opciones de configuración de la aplicación

Para permitir la configuración de los  parámetros relacionados con la conexión hacia la base de datos, ha sido necesario modificar el fichero `./spring-app/src/main/resources/application.properties` para parametrizar las siguientes propiedades:

* host de base de datos 
* puerto de base de datos
* nombre de base de datos
* usuario 
* contraseña

De manera que el fichero `application.properties` queda de la siguiente manera:

```properties
...
spring.datasource.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/{DB_SCHEMA}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_USER_PASSWD}
...
```

<a name=dockerfile></a>
## Dockerfile para la construcción del contenedor

Antes de proceder a la construcción de la imagen podemos editar el fichero `./spring-data/pom.xml`, para poder modificar los valores de: `groupId`, `artifactId`y `version`, quedando de la siguiente manera:

```xml
<groupId>com.keepcoding</groupId>
<artifactId>spring-app</artifactId>
<version>0.1.0</version>
```
de esta manera obtendremos el artefacto con el nombre: `spring-app-0.1.0.jar`

A continuación, mostramos el Dockerfile para la construcción de la imagen de la aplicación:

```dockerfile
# Fase de construccion del artefacto
FROM maven:3-openjdk-8 as builder
WORKDIR /opt/spring-app
COPY ./spring-app ./
RUN mvn package

# Fase de construccion de la imagen final
FROM openjdk:8-alpine
EXPOSE 8080
COPY --from=builder /opt/spring-app/target/spring-app-0.1.0.jar /opt
WORKDIR /opt

CMD ["java", "-jar", "spring-app-0.1.0.jar"]
```

<a name=construccion-imagen></a>
## Construcción de la imagen y subida a Docker Hub

Para la construcción de la imagen ejecutaremos:

```
docker build -t amoragon/spring-app .
```

A continuación subimos a Docker Hub: 

```
docker push amoragon/spring-app
```

<a name=standalone></a>
## Prueba de funcionamiento en local - contenedores 

Para probar el contenedor lo haremos sobre una red concreta. Esto lo haremos con:

```
docker network create spring-app-network
```

A continuación, necesitaremos lanzar un contenedor con la base de datos con el siguiente comando:

```
docker run -d --rm --name spring-app-db -v mariadb-data:/var/lib/mysql \
    --env MARIADB_USER=... \
    --env MARIADB_PASSWORD=... \
    --env MARIADB_ROOT_PASSWORD=... \
    --env MARIADB_DATABASE=spring_app \
    --network spring-app-network \
    mariadb
```
__Nota:__ Para consultar más opciones de configuración de la imagen de MariaDB, consultar la [información oficial en Docker Hub](https://hub.docker.com/_/mariadb).

Hacemos uso de un volumen gestionado por Docker para el almacenamiento de los datos de la base de datos. Por otro lado, indicamos la red que hemos creado previamente.

Finalmente, lanzamos el contenedor con la imagen de la aplicación con el comando siguiente:

```
docker run -d --rm --network spring-app-network \
    --env DB_HOST=spring-app-db \
    --env DB_PORT=3306 \
    --env DB_USER=... \
    --env DB_USER_PASSWD=... \
    --env DB_SCHEMA=spring_app \
    --name spring-app \
    amoragon/spring-app
```

Para poder probar el contenedor lanzamos un contenedor que se encuentre dentro de la misma red para poder hacer `curl` a la url del contenedor de la aplicación. Así pues lanzaremos la imagen con el siguiente comando:

```
docker run -it --rm --network spring-app-network alpine/curl sh
```
Una vez dentro del contenedor ejecutaremos:

```
curl http://spring-app:8080/demo/all
```
y veremos que la salida es `[]`, ya que no hay ningún dato almacenado. Si a continuación lanzamos la petición:

```
curl http://spring-app:8080/demo/add -d name=John -d email=john@example.com
```

Obtendremos `Saved`. Si volvemos a ejecutar el comando `curl http://spring-app:8080/demo/all`, obtendremos:

```json
[{"id":1,"name":"John","email":"john@example.com"}]
```

Si quisieramos hacer la comprobación de los datos almacenados desde el navegador también podríamos haber expuesto el contenedor de la aplicación en un puerto. Por ejemplo:

```
docker run -d --rm --network spring-app-network \
    -p 80:8080 \
    --env DB_HOST=spring-app-db \
    --env DB_PORT=3306 \
    --env DB_USER=... \
    --env DB_USER_PASSWD=... \
    --env DB_SCHEMA=spring_app \
    --name spring-app \
    spring-app
```
De manera que consultando la url `http://localhost/demo/all` podríamos ver los datos insertados. Sin embargo, para insertar datos podemos hacer uso de alguna herramienta como [Postman](https://www.postman.com/).

<a name=compose></a>
## Prueba de funcionamiento en local - docker compose

Construimos el siguiente docker compose para la aplicación y la base de datos:

```yaml
version: "3"
services:
  spring-app-db:
    container_name: spring-app-db
    image: mariadb
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - spring-app-network

  spring-app:
    depends_on:
      - spring-app-db
    build: .
    container_name: spring-app
    restart: always
    environment:
      DB_HOST: ${DB_HOST}
      DB_PORT: ${DB_PORT}
      DB_USER: ${DB_USER}
      DB_USER_PASSWD: ${DB_USER_PASSWD}
      DB_SCHEMA: ${DB_SCHEMA}
    ports:
      - 80:8080
    networks:
      - spring-app-network

volumes:
  mariadb-data:

networks:
  spring-app-network:
    driver: bridge
```
En el fichero `docker-compose.yml`se han parametrizado los valores de las variables de entorno con un fichero llamado `variables.env`, cualquier modificación de estos valores puede realizarse ahí.

```properties
# Variables de entorno para el contenedor de MariaDB
MARIADB_ROOT_PASSWORD="..."
MARIADB_USER="..."
MARIADB_PASSWORD="..."
MARIADB_DATABASE="spring_app"

# Variables de entorno para el contenedor de spring-app
DB_HOST="spring-app-db"
DB_PORT="3306"
DB_USER="..."
DB_USER_PASSWD="..."
DB_SCHEMA="spring_app"
```

Para ejecutarlo, lo lanzamos con el comando `docker-compose --env-file variables.env up -d`.

Para comprobar que la aplicación responde correctamente, introducimos en el navegador la dirección `http://localhost/demo/all`. En caso de no tener ningún dato todavía, no obtendremos datos de la aplicación.

Para poder realizar la inserción de registros en la base de datos lo realizamos desde un contenedor que conecte a la misma red creada por docker compose. Para esto primero consultamos la red creada por docker-compose con:

```
docker network ls 
```
En nuestro caso la red obtenida es `practica_spring-app-network`. 

Ahora lanzamos el contenedor con la instrucción:

```
docker run -it --rm --network practica_spring-app-network alpine/curl sh
```

Una vez dentro del contenedor lanzamos la petición siguiente:

```
curl http://spring-app:8080/demo/add -d name=John -d email=john@example.com
```

Una vez hecho esto, podemos volver a comprobar el navegador y se nos devolverán los registros insertados.

[Volver al índice](#indice)

[Volver al índice principal](../README.md)