FROM docker.io/rakudo-star:latest

RUN apt-get update -y && \
    apt-get install -y build-essential && \
    apt-get purge -y

RUN mkdir /src
COPY . /src
WORKDIR /src
RUN zef install --/test --deps-only .

