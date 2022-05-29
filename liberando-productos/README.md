# Práctica Liberando Productos - Antonio Moragón


<a name="indice"></a>
## Índice

* [Enunciado y requerimientos](#enunciado)
    * [Mejoras a realizar](#mejoras)   
* [Nuevo endpoint y tests unitarios](#nuevo-endpoint)
    * [Ejecución del código en local](#ejecucion-local)
    * [Ejecución de tests unitarios en local](#tests)
* [Pipeline CI/CD](#pipeline)
    * [Pipeline Testing](#testing)
    * [Pipeline Build & Push](#build-push)
* [Monitorización y alertas](#monitorizacion)
    * [Ejecución de Prometheus](#ejecucion-prometheus)
    * [Configuración alerta de consumo de CPU](#alerta-cpu)
    * [Comprobación funcionamiento alerta](#comprobacion-alerta)
    * [Grafana](#grafana)
    * [Acceso a aplicaciones](#acceso-aplicaciones)

<a name="enunciado"></a>
## Enunciado y requerimientos

El objetivo es mejorar un proyecto creado previamente para ponerlo en producción, a través de la adicción de una serie de mejoras.

El proyecto inicial es un servidor que realiza lo siguiente:

- Utiliza [FastAPI](https://fastapi.tiangolo.com/) para levantar un servidor en el puerto `8081` e implementa inicialmente dos endpoints:
  - `/`: Devuelve en formato `JSON` como respuesta `{"health": "ok"}` y un status code 200.
  - `/health`: Devuelve en formato `JSON` como respuesta `{"message":"Hello World"}` y un status code 200.

<a name="mejoras"></a>
### Mejoras a realizar

* Añadir por lo menos un nuevo endpoint a los existentes `/` y `/health`
* Creación de tests unitarios para el nuevo endpoint añadido
* Opcionalmente creación de helm chart para desplegar la aplicación en Kubernetes
* Creación de pipelines de CI/CD en cualquier plataforma (Github Actions, Jenkins, etc) que cuenten por lo menos con las siguientes fases: __Testing__ y __Build & Push__ (creación de imagen docker y push de la misma a cualquier registry válido)
* Configurar monitorización mediante prometheus en los nuevos endpoints añadidos, por lo menos con la siguiente configuración:
    * Contador cada vez que se pasa por el/los nuevo/s endpoint/s, tal y como se ha realizado para los endpoints implementados inicialmente.
* Desplegar prometheus a través de Kubernetes mediante minikube y configurar alert-manager para por lo menos las siguientes alarmas:
    * Uso de CPU de un contenedor mayor al del límite configurado
* Las alarmas configuradas deberán tener severity high o critical
* Crear canal en slack `<nombreAlumno>-prometheus-alarms` y configurar webhook entrante para envío de alertas con alert manager
* Alert manager estará configurado para lo siguiente:
    * Mandar un mensaje a Slack en el canal configurado en el paso anterior con las alertas con label "severity" y "critical"
    * Deberán enviarse tanto alarmas como recuperación de las mismas
    * Habrá una plantilla configurada para el envío de alarmas
* Creación de un dashboard de Grafana, con por lo menos lo siguiente:
    * Número de llamadas a los endpoints
    * Número de veces que la aplicación ha arrancado

[Volver al índice](#indice)

<a name="nuevo-endpoint"></a>
## Nuevo endpoint y tests unitarios

Se modifica el fichero [`src/application/app.py`](src/application/app.py) para añadir el nuevo endpoint:

```python
@app.get("/bye")
async def read_bye():
    """Implement bye endpoint"""
    # Increment counter used for register the total number of calls in the webserver
    REQUESTS.inc()
    # Increment counter used for register the total number of calls in the main endpoint
    BYE_ENDPOINT_REQUESTS.inc()
    return {"msg": "Bye Bye"}
```

Se modifica el fichero [`src/tests/app_test.py`](src/tests/app_test.py) para añadir el nuevo test que prueba el endpoint añadido:

```python
@pytest.mark.asyncio
async def read_bye_test(self):
    """Tests the bye endpoint"""
    response = client.get("/bye")

    assert response.status_code == 200
    assert response.json() == {"msg": "Bye Bye"}
```

[Volver al índice](#indice)

<a name="ejecucion-local"></a>
### Ejecución del código en local

En primer lugar creamos el entorno virtual para la instalación de las dependencias necesarias de la aplicación:

```sh
python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

Una vez hecho esto podremos ejecutar la aplicación con:

```sh
python3 src/app.py
```

Para salir del entorno virtual bastará con ejecutar:

```sh 
deactivate
```

Una vez arrancada la aplicación podremos probar los diferentes endpoints:

* [http://localhost:8081](http://localhost:8081)
* [http://localhost:8081/health](http://localhost:8081/health)
* [http://localhost:8081/bye](http://localhost:8081/bye)

Finalmente en la dirección [http://localhost:8081/docs](http://localhost:8081/docs) se puede consultar el endpoint que implementa OpenAPI, para consultar todos los endpoints indicados y poder probarlos directamente desde esta web.

[Volver al índice](#indice)

<a name="tests"></a>
### Ejecución de tests unitarios en local 

Si ya contamos con el entorno virtual creado, bastará con activar dicho entorno, para esto:

```sh
source venv/bin/activate
```

Si no contamos con dicho entorno virtual, ver el [punto anterior](#ejecucion-local).

Para ejecutar todos los tests bastará con alguna de las siguientes formas dependiendo de si queremos ver o no la cobertura de dichos tests, y la generación de un report de dicha ejecución.

```sh
pytest # ejecución de todos los tests
pytest --cov # ejecución de todos los tests y mostrar cobertura
pytest --cov --cov-report=html # ejecución de todos los tests y generación de report de cobertura  
```

[Volver al índice](#indice)

<a name="pipeline"></a>
## Pipeline CI/CD 

Se ha optado por la implementación del pipeline de CI/CD haciendo uso de GitHub Actions. Para esto se han implementado dos pipelines: 

* uno para la fase de tests ([.github/workflows/python-app-testing.yml](.github/workflows/python-app-testing.yml)) y,
* otro ([.github/workflows/build-and-publish-docker-image.yml](.github/workflows/build-and-publish-docker-image.yml)) para la construcción de la imagen y publicación en repositorio

[Volver al índice](#indice)

<a name="testing"></a>
### Pipeline Testing

Se ha configurado para que la ejecución de los tests se realice sobre las versiones 3.8 y 3.9 de python mediante la siguiente configuración:

```yaml
jobs:
  build:

    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.8", "3.9"]
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v3
      with:
        python-version: ${{ matrix.python-version }}
    ...
```

[Volver al índice](#indice)

<a name="build-push"></a>
### Pipeline Build & Push

Se ha optado por publicar la imagen en Docker Hub, en lugar del registry de Github. Por tanto el nombre de la imagen debe ser `<nombre_usuario>/<nombre_a_elegir>:<tag>`.

El pipeline de Github Actions en la variable `${{ github.repository }}` devuelve el nombre del repositorio, en nuestro caso este valor sería: `KeepCodingCloudDevops5/liberando-productos-antonio`, por lo que es necesario editar este valor para su publicación. Esto se ha solucionado de la siguiente manera:

```yaml
...
env:
  DOCKERHUB_USER: amoragon

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up docker image name
        run: |
          # ${{ github.repository }} devuelve KeepCodingCloudDevops5/liberando-productos-antonio y queremos amoragon/liberando-productos-antonio
          echo IMAGE_NAME=$DOCKERHUB_USER/$(echo ${{ github.repository }} | cut -d / -f 2):${{ github.ref_name }} >> $GITHUB_ENV
          echo IMAGE_NAME_LATEST=$DOCKERHUB_USER/$(echo ${{ github.repository }} | cut -d / -f 2):latest >> $GITHUB_ENV
...
```

[Volver al índice](#indice)

<a name="monitorizacion"></a>
## Monitorización y alertas

Para la monitorización de la aplicación se hace uso del cliente de prometheus en la aplicación, el cuál expone en la dirección [http://localhost:8000](http://localhost:8000) las metricas siguientes:

* `healthcheck_requests_total`. Cuenta el número de veces que se accede al endpoint `http://localhost:8081/health`
* `main_requests_total`. Cuenta el número de veces que se accede al endpoint `http://localhost:8081/`
* `bye_requests_total`. Cuenta el número de veces que se accede al endpoint `http://localhost:8081/bye`
* `server_requests_total`. Cuenta el número de veces total que se ha accedido a todos los endpoint anteriores.

__Nota:__ Para poder acceder a través de localhost es necesario configurar el acceso a las aplicaciones mediante `port-forward`. Explicado en la sección [Acceso a aplicaciones](#acceso-aplicaciones).

[Volver al índice](#indice)

<a name="ejecucion-prometheus"></a>
### Ejecución de Prometheus

**Software necesario**

* [minikube](https://minikube.sigs.k8s.io/docs/)
* [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
* [helm](https://helm.sh/)

Para poder recabar las métricas expuestas necesitamos levantar Prometheus. Para esto se hará uso de `minikube`, siguiendo los siguientes pasos:

* Levantamos cluster de `minikube` con:

```sh
minikube start --kubernetes-version='v1.21.1' --memory=4096 -p liberando-productos-practica
```

* Levantamos prometheus con:

```sh
helm -n liberando-productos-practica upgrade --install prometheus prometheus-community/kube-prometheus-stack -f ./prometheus/custom_values_prometheus.yaml --create-namespace --wait --version 34.1.1
```

* Instalamos metrics-server en minikube a través de la activación del addon necesario:

```sh
minikube addons enable metrics-server -p liberando-productos-practica
```

* Levantamos nuestra aplicación con helm:

```sh
helm -n liberando-productos-practica install -f charts/myvalues.yaml keepcoding charts/python-app
```

[Volver al índice](#indice)

<a name="alerta-cpu"></a>
### Configuración alerta de consumo de CPU

Para la configuración de la alerta de consumo de CPU se proporciona el fichero [`prometheus/custom_values_prometheus.yaml`](prometheus/custom_values_prometheus.yaml).

```yaml
...
additionalPrometheusRulesMap:
  rule-name:
    groups:
      - name: PythonAppRuleSet
        rules:
          - alert: pythonAppConsumingMoreThanRequest
            expr: avg by(pod) (container_cpu_usage_seconds_total{container="python-app"}) > avg by(pod) (kube_pod_container_resource_requests{container="python-app",resource="cpu"})
            for: 0m
            labels:
              severity: critical
              alertname: "python-app container is consuming more than requested"
            annotations:
              summary: Pod {{ $labels.pod }} consuming more than requested
              description: "Pod more less than request"
              message: Pod {{ $labels.pod }} is consuming more than requested
```

Además esta alerta se lanzará en el canal `#antonio-moragon-prometheus-alarms` para esto la sección de `alert-manager` del fichero [`prometheus/custom_values_prometheus.yaml`](prometheus/custom_values_prometheus.yaml), se configura de la siguiente manera:

```yaml
...
alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['job']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'slack'
      routes:
      - match:
          alertname: Watchdog
        receiver: 'null'
    # This inhibt rule is a hack from: https://stackoverflow.com/questions/54806336/how-to-silence-prometheus-alertmanager-using-config-files/54814033#54814033
    inhibit_rules:
      - target_match_re:
           alertname: '.+Overcommit'
        source_match:
           alertname: 'Watchdog'
        equal: ['prometheus']
    receivers:
    - name: 'null'
    - name: 'slack'
      slack_configs:
      - api_url: 'https://hooks.slack.com/services/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' # URL webhook creado
        send_resolved: true
        channel: '#antonio-moragon-prometheus-alarms' # Canal de slack que recibe las notificaciones
        title: '[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] Monitoring Event Notification'
        text: |-
          {{ range .Alerts }}
            *Alert:* {{ .Labels.alertname }} - `{{ .Labels.severity }}`
            *Description:* {{ .Annotations.message }}
            *Graph:* <{{ .GeneratorURL }}|:chart_with_upwards_trend:> *Runbook:* <{{ .Annotations.runbook_url }}|:spiral_note_pad:>
            *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
...
```

[Volver al índice](#indice)

<a name="comprobacion-alerta"></a>
### Comprobación funcionamiento alerta

A continuación detallamos los pasos para forzar el uso de cpu del contenedor para forzar la alerta. 

* Primero deberemos conectarnos al POD que está ejecutando la aplicación. Obtenemos el nombre del pod creado mediante: 

```sh
export POD_NAME=$(kubectl get pods --namespace liberando-productos-practica -l "app.kubernetes.io/name=python-app,app.kubernetes.io/instance=keepcoding" -o jsonpath="{.items[0].metadata.name}")
```

* Nos conectamos al pod:

```sh
kubectl -n liberando-productos-practica exec -it $POD_NAME -- /bin/sh
```

* Instalación de software necesario 

```sh
apk update && apk add git go
```

* Descargamos herramienta para realizar la prueba de estrés:

```sh
git clone https://github.com/jaeg/NodeWrecker.git
cd NodeWrecker
go build -o extress main.go
```

A los pocos segundos de ejecutar la prueba de estrés se recibe una alerta en el canal de slack configurado, tal y como se puede ver en la imagen inferior. Después de un tiempo, se recibe el mensaje de recuperación de la alarma en cuestión.

![alerta-slack](images/slack-alert-notification.png)

[Volver al índice](#indice)

<a name="grafana"></a>
## Grafana

En el fichero [`grafana/liberando-productos-dashboard.json`](grafana/liberando-productos-dashboard.json) se proporciona un dashboard de Grafana donde se muestran las métricas:

* `healthcheck_requests_total`
* `main_requests_total`
* `bye_requests_total`
* `server_requests_total`

y también la métrica,

* `kube_pod_container_status_restarts_total`, que muestra el número de veces que se ha iniciado la aplicación.

[Volver al índice](#indice)

<a name="acceso-aplicaciones"></a>
## Acceso a aplicaciones

Para habilitar el acceso a Prometheus, Grafana y nuestra aplicación, lo haremos mediante `port-forward` hacia los servicios de cada una de ellas.

* Acceso a Prometheus

```sh
kubectl -n liberando-productos-practica port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
```

* Acceso a Grafana

```sh
kubectl -n liberando-productos-practica port-forward svc/prometheus-grafana 3000:80
```

__Usuario:__ admin __Contraseña:__ prom-operator

* Acceso a aplicación

```sh
kubectl -n liberando-productos-practica port-forward svc/keepcoding-python-app 8081:8081
```

* Acceso a las métricas de Prometheus de la aplicación

```sh
kubectl -n liberando-productos-practica port-forward svc/keepcoding-python-app 8000:8000
```
[Volver al índice](#indice)




