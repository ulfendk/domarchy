# xrdp isn't in the official Arch repos, only the AUR, so it has to be
# built from source. Do that in a throwaway stage so the final image
# doesn't carry the compiler toolchain.
FROM archlinux:latest AS xrdp-builder

RUN pacman -Syu --noconfirm --needed \
    base-devel git sudo nasm cmocka \
    libxrandr libfdk-aac ffmpeg imlib2 fuse3 x264 openssl pam

RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder

USER builder
WORKDIR /home/builder
RUN git clone https://aur.archlinux.org/xrdp.git && \
    cd xrdp && \
    makepkg -s --noconfirm --nocheck

FROM archlinux:latest

RUN pacman -Syu --noconfirm --needed \
    qemu-system-x86 qemu-img edk2-ovmf wget qemu-audio-pa samba \
    libxrandr libfdk-aac ffmpeg imlib2 fuse3 x264 openssl pam

COPY --from=xrdp-builder /home/builder/xrdp/*.pkg.tar.zst /tmp/
RUN pacman -U --noconfirm /tmp/*.pkg.tar.zst && rm -f /tmp/*.pkg.tar.zst

EXPOSE 3389

COPY entrypoint.sh /entrypoint.sh
COPY xrdp.ini /etc/xrdp/xrdp.ini
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
