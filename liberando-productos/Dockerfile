FROM python:3.9-alpine

WORKDIR /opt
COPY requirements.txt .
COPY ./src/ .

RUN pip install --upgrade pip
RUN pip install -r requirements.txt

EXPOSE 8081

CMD ["python3", "-u", "app.py"]