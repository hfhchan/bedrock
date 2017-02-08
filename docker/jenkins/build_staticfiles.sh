#!/bin/bash

set -euxo pipefail

python manage.py collectstatic --noinput -v 0
python docker/bin/softlinkstatic.py
