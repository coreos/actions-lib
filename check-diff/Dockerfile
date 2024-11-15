FROM registry.fedoraproject.org/fedora:latest
RUN dnf install -y python
COPY check-diff.py /usr/bin/check-diff
ENTRYPOINT ["/usr/bin/check-diff"]
