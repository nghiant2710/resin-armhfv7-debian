#!/bin/bash

QEMU_VERSION='2.5.0-resin-rc1'
QEMU_SHA256='8db1c7525848072974580b2e1c79797fc995fd299ee2e4214631574023589782'
SUITES='sid wheezy jessie'
MIRROR='ftp://ftp.debian.org/debian/'
REPO='resin/armv7hf-debian'
LATEST='jessie'

# Download QEMU
curl -SLO https://github.com/resin-io/qemu/releases/download/$QEMU_VERSION/qemu-$QEMU_VERSION.tar.gz \
	&& echo "$QEMU_SHA256  qemu-$QEMU_VERSION.tar.gz" > qemu-$QEMU_VERSION.tar.gz.sha256sum \
	&& sha256sum -c qemu-$QEMU_VERSION.tar.gz.sha256sum \
	&& tar -xz --strip-components=1 -f qemu-$QEMU_VERSION.tar.gz

docker build -t armv7hfdebian-mkimage .

for suite in $SUITES; do

	rm -rf output
	mkdir -p output
	docker run --rm --privileged	-e REPO=$REPO \
									-e SUITE=$suite \
									-e MIRROR=$MIRROR \
									-v `pwd`/output:/output armv7hfdebian-mkimage

	docker build -t $REPO:$suite output/
	docker run --rm $REPO:$suite bash -c 'dpkg-query -l' > $suite

	# Upload to S3 (using AWS CLI)
	printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
	aws s3 cp $suite s3://$BUCKET_NAME/image_info/armv7hf-debian/$suite/
	aws s3 cp $suite s3://$BUCKET_NAME/image_info/armv7hf-debian/$suite/$suite_$date
	rm -rf $suite
	
	docker tag -f $REPO:$suite $REPO:$suite-$date
	if [ $LATEST == $suite ]; then
		docker tag -f $REPO:$suite $REPO:latest
	fi
done

rm -rf qemu*
docker push resin/armv7hf-debian
