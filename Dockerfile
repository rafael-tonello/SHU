#build with 'podman build -t shu-cli-dev .' or 'docker build -t shu-cli-dev .'

#docker file for run tests
FROM ubuntu:24.10

# Install dependencies
RUN apt-get update
RUN apt-get install -y wget git
RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -O /tmp/go.tar.gz
RUN tar -C /usr/local -xzf /tmp/go.tar.gz

RUN echo 'export GOROOT=/usr/local/go' >> /root/.bashrc
RUN echo 'export GOPATH=$HOME/go' >> /root/.bashrc
RUN echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> /root/.bashrc

RUN echo 'export GOROOT=/usr/local/go' >> /root/.profile
RUN echo 'export GOPATH=$HOME/go' >> /root/.profile
RUN echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> /root/.profile

ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

RUN go install github.com/mikefarah/yq/v4@latest


COPY ./src /opt/src
COPY ./src/tools/shhotreload.sh /usr/bin/shhotreload.sh
RUN chmod +x /usr/bin/shhotreload.sh
WORKDIR /opt/src

CMD ["/bin/bash", "-c", "/opt/src/shu-cli.test.sh"]


