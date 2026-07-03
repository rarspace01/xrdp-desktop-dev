FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV SDKMAN_DIR=/root/.sdkman
ENV PATH="${SDKMAN_DIR}/candidates/java/current/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       xfce4 xfce4-terminal xorgxrdp xrdp dbus-x11 sudo ca-certificates wget curl unzip zip libxtst6 \
       vlc pulseaudio libreoffice gimp
#    && rm -rf /var/lib/apt/lists/* \

#install intellij
RUN curl -fsSL -o idea.tar.gz https://download.jetbrains.com/idea/idea-2026.1.4.tar.gz\ 
    && mkdir -p /opt/intellij \
    && tar --strip-components=1 -xzf idea.tar.gz -C /opt/intellij \
    && ln -s /opt/intellij/bin/idea.sh /usr/local/bin/idea \
    && rm -rf idea.tar.gz

# install sdkman & java
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -lc "source /root/.sdkman/bin/sdkman-init.sh && sdk install java 25.0.1-tem && sdk default java 25.0.1-tem"

ARG USER=developer
ARG PASS=developer
RUN useradd -m -s /bin/bash ${USER} \
    && echo "${USER}:${PASS}" | chpasswd \
    && usermod -aG sudo ${USER}

RUN echo "startxfce4" > /etc/skel/.xsession \
    && cp /etc/skel/.xsession /home/${USER}/.xsession \
    && chown ${USER}:${USER} /home/${USER}/.xsession

# Ensure xrdp config exists; allow use of /etc/xrdp if present
RUN mkdir -p /etc/xrdp || true

# Startup script
RUN printf '#!/bin/bash\nset -e\nif [ -x "/etc/init.d/dbus" ]; then /etc/init.d/dbus start; fi\n/usr/sbin/xrdp-sesman --nodaemon &\nexec /usr/sbin/xrdp --nodaemon\n' > /start.sh \
    && chmod +x /start.sh

EXPOSE 3389
VOLUME ["/home/${USER}"]
CMD ["/start.sh"]

# Notes: build with --build-arg USER=youruser --build-arg PASS=yourpass to set credentials