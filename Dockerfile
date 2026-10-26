FROM swift:6.4-trixie@sha256:102021d352b590618c836aad19cb0c6eab1546d9d0f9be8886aa529ceb0919b3 AS build

ARG VERSION=604.0.0
WORKDIR /swift-format
ADD --checksum=sha256:43f7f4d039dd85733fdb6119dcd29271d08936592ee9904840f0fd743b061894 https://github.com/swiftlang/swift-format/archive/${VERSION}.tar.gz /swift-format/
RUN tar zxf ${VERSION}.tar.gz --strip-components 1
RUN swift build --product swift-format --configuration release --static-swift-stdlib --build-system native

FROM gcr.io/distroless/cc-debian13:debug@sha256:85695d9865b8130f1ecc8f87da224fbae4ddcb56830a514840bcb12191feefd7
LABEL org.opencontainers.image.source=https://github.com/banterability/swift-format-image
COPY --from=build /swift-format/.build/release/swift-format /usr/bin/
COPY --from=build /swift-format/LICENSE.txt /etc/LICENSE.txt
ENTRYPOINT ["/usr/bin/swift-format"]
