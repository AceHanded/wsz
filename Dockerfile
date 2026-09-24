FROM baredevcontainer/zig:0.15.2-trixie-20260923 AS build

WORKDIR /src

COPY . .

RUN zig build -Doptimize=ReleaseSmall

FROM scratch

COPY --from=build /src/zig-out/bin/wsz /wsz

ENTRYPOINT ["/wsz"]