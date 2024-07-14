FROM docker.io/rakudo-star:latest

# Install make, gcc, etc.
RUN apt-get update -y && \
    apt-get install -y build-essential && \
    apt-get purge -y

# Copy in Raku source code and build
RUN mkdir -p /opt/rakuast-rakudoc-render
COPY . /opt/rakuast-rakudoc-render
WORKDIR /opt/rakuast-rakudoc-render
RUN zef install --/test --deps-only .

# symlink executable to location on PATH
RUN ln -s /opt/rakuast-rakudoc-render/bin/RenderDocs /usr/local/bin/RenderDocs


# Make a new WORKDIR where users will mount their code
RUN mkdir /src
WORKDIR /src

