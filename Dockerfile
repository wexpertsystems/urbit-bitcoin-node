# bitcoind Builder container
FROM buildpack-deps:bullseye-curl as btc-builder

# This buildarg can be set during container build time with --build-arg VERSION=[version]
ARG VERSION=0.21.2

RUN apt-get update && \
  apt-get install -y gnupg2 && \
  rm -rf /var/lib/apt/lists/*

COPY ./bin/get-bitcoin.sh /usr/bin/
RUN chmod +x /usr/bin/get-bitcoin.sh && \
  mkdir /root/bitcoin && \
  get-bitcoin.sh $VERSION /root/bitcoin/


# electrs Builder container
FROM rust:1.55.0 as electrs-builder

RUN apt-get update && \
  apt-get install -y clang cmake build-essential && \
  rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/romanz/electrs.git
RUN cd electrs && cargo build --locked --release


# NodeJS Builder container
FROM buildpack-deps:bullseye-curl as nodejs-builder

RUN apt-get update && \
  apt-get install -y xz-utils python && \
  rm -rf /var/lib/apt/lists/*

RUN curl https://nodejs.org/dist/v14.18.1/node-v14.18.1-linux-x64.tar.xz --output node-v14.18.1-linux-x64.tar.xz
RUN tar xvf node-v14.18.1-linux-x64.tar.xz


# urbit-bitcoin-rpc Builder container
FROM buildpack-deps:bullseye as urbit-rpc-builder

ADD https://api.github.com/repos/urbit/urbit-bitcoin-rpc/git/refs/heads/master version.json
RUN git clone -b master https://github.com/urbit/urbit-bitcoin-rpc.git urbit-bitcoin-rpc


# urbit-bitcoin-node container
FROM debian:bullseye-slim

# Run bitcoin as a non-privileged user to avoid permissions issues with volume mounts,
# amount other things.
#
# These buildargs can be set during container build time with --build-arg UID=[uid]
ARG UID=1000
ARG GID=1000
ARG USERNAME=user

RUN apt-get update && \
  apt-get install -y iproute2 sudo && \
  rm -rf /var/lib/apt/lists/*

# used to set internal docker domain while still not running as root user.
COPY ./bin/append-to-hosts.sh /usr/bin/append-to-hosts
RUN chmod +x /usr/bin/append-to-hosts

# Allow the new user write access to /etc/hosts
RUN groupadd -g $GID -o $USERNAME && \
  useradd -m -u $UID -g $GID -o -d /home/$USERNAME -s /bin/bash $USERNAME && \
  echo "$USERNAME    ALL=(ALL:ALL) NOPASSWD: /usr/bin/append-to-hosts" | tee -a /etc/sudoers

# Copy files from the builder containers
COPY --from=btc-builder /root/bitcoin/ /usr/local/
COPY --from=electrs-builder /electrs/target/release/electrs /usr/local/bin
COPY --from=nodejs-builder /node-v14.18.1-linux-x64/ /usr/local/
COPY --from=urbit-rpc-builder /urbit-bitcoin-rpc/* /
COPY --from=urbit-rpc-builder /urbit-bitcoin-rpc/src /src

# Overwrite two files in the dist with our local slightly modified versions
ADD /rpc/mainnet-start.sh /mainnet-start.sh
ADD /rpc/bitcoin.conf /bitcoin.conf

RUN npm install express
RUN npm audit fix


RUN mkdir -p /bitcoin/data && \
  chown -R $USERNAME:$GID /bitcoin

USER $USERNAME

EXPOSE 8332 8333 50002

ENTRYPOINT ["/mainnet-start.sh"]




