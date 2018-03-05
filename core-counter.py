import multiprocessing
import os

dir = os.path.dirname(__file__)

with open(os.path.join(dir, 'httpd.conf')) as config:
    config_dict = dict()
    for line in config:
        line_parts = line.split()
        config_dict[line_parts[0]] = line_parts[1]
    if config_dict.get('cpu_limit'):
        print(config_dict.get('cpu_limit'))
    else:
        print(multiprocessing.cpu_count())
