FROM amoragon/base-jenkins-agent

WORKDIR /opt

# Terraform installation 
COPY terraform_1.1.7_linux_arm64.zip .
RUN unzip terraform_1.1.7_linux_arm64.zip && \
    mv terraform /usr/local/bin && \
    rm terraform_1.1.7_linux_arm64.zip

# AWS cli installation
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm awscliv2.zip
