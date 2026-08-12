# syntax=docker/dockerfile:1
FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
# Installed outside /root so the runtime user (whoever it turns out to be) can read it
ENV SDKMAN_DIR=/opt/sdkman
ENV PATH="${SDKMAN_DIR}/candidates/java/current/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       xfce4 xfce4-terminal xorgxrdp xrdp dbus-x11 sudo ca-certificates wget curl unzip zip libxtst6 \
       vlc pulseaudio libreoffice gimp
#    && rm -rf /var/lib/apt/lists/* \

#install intellij
RUN curl -fsSL -o idea.tar.gz https://download.jetbrains.com/idea/idea-2026.1.4.tar.gz \
    && mkdir -p /opt/intellij \
    && tar --strip-components=1 -xzf idea.tar.gz -C /opt/intellij \
    && ln -s /opt/intellij/bin/idea.sh /usr/local/bin/idea \
    && rm -rf idea.tar.gz

# install sdkman & java
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -lc "source ${SDKMAN_DIR}/bin/sdkman-init.sh && sdk install java 25.0.1-tem && sdk default java 25.0.1-tem" \
    && chmod -R a+rX "${SDKMAN_DIR}"

# Fixed account name; the password is set at container start, see /start.sh
ENV XRDP_USER=developer
# Default only -- override at run time: docker run -e XRDP_PASS=yourpass
ENV XRDP_PASS=developer

# Ensure xrdp config exists; allow use of /etc/xrdp if present
RUN mkdir -p /etc/xrdp || true

# Account is created here, but deliberately left without a password
RUN echo "startxfce4" > /etc/skel/.xsession \
    && useradd -m -s /bin/bash "${XRDP_USER}" \
    && usermod -aG sudo "${XRDP_USER}"

# Startup script
COPY <<'EOF' /start.sh
#!/bin/bash
set -e

XRDP_USER="${XRDP_USER:-developer}"
XRDP_PASS="${XRDP_PASS:-developer}"

# Applied on every start, so no password is ever baked into an image layer
echo "$XRDP_USER:$XRDP_PASS" | chpasswd

# Fallback for bind-mounted homes, which do not inherit /etc/skel
XRDP_HOME="$(getent passwd "$XRDP_USER" | cut -d: -f6)"
if [ ! -f "$XRDP_HOME/.xsession" ]; then
    echo "startxfce4" > "$XRDP_HOME/.xsession"
    chown "$XRDP_USER":"$XRDP_USER" "$XRDP_HOME/.xsession"
fi

if [ -x /etc/init.d/dbus ]; then /etc/init.d/dbus start; fi

/usr/sbin/xrdp-sesman --nodaemon &
exec /usr/sbin/xrdp --nodaemon
EOF
RUN chmod +x /start.sh

EXPOSE 3389
VOLUME ["/home/developer"]
CMD ["/start.sh"]

# Notes: run with -e XRDP_PASS=yourpass to set the password for the "developer" account
