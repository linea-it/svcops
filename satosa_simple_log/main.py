#!/bin/python3
import logging
import logging.config
import yaml
import re
import os
import xmltodict
from tail import tail

ATTRS = [
    {'attr': 'AssertionConsumerServiceURL', 'regex': False},
    {'attr': 'Destination'},
    {'attr': 'ID'},
    {'attr': 'InResponseTo'},
]

NODES = [
    {'node': '(ns\d:Attribute$)', 'attr': '@FriendlyName', 'regex': True},
]

FILE_MONITORED = os.environ.get('SATOSA_FILE_MONITORED', 'logs/monitoring.log')
LOG_CONFIG = os.environ.get('SATOSA_LOG_CONFIG', 'logging.yml')
DELAY = os.environ.get('SATOSA_DELAY', 5)

with open(LOG_CONFIG, 'r') as stream:
    config = yaml.load(stream, Loader=yaml.FullLoader)

logging.config.dictConfig(config)
logger = logging.getLogger('simpleExample')


def print_line(txt):
    """ Prints received text """

    try:
        xml_matched = re.search("<ns\d:.*</ns\d:.*>", txt)
        msg_matched = None

        for matched in ["^\d+.* ERROR:.*", "^\d+.* WARNING:(.*)"]:
            if re.search(matched, txt):
                msg_matched = re.search(matched, txt)
                break

        if xml_matched:
            xml = xml_matched.group(0)
            msg = parse_xml_to_string(xml)
            if msg:
                logmsg = re.sub("<ns\d:.*</ns\d:.*>", msg, txt)
                logmsg = logmsg.replace("\n", "")
                logger.info(logmsg)
            else:
                logger.debug("No match in attributes and nodes")
        elif msg_matched:
            msg = msg_matched.group(0)
            msg = msg.replace("\n", "")
            logger.info(msg)
        else:
            logger.debug("Unmatched regular expressions.")
    except Exception as e:
        logger.error(e)


def parse_xml_to_string(xml):
    """ Parses xml to string """
    dic = xmltodict.parse(xml)
    ret_list = []

    for attr_dic in ATTRS:
        attr, regex = attr_dic.get('attr'), attr_dic.get('regex', False)
        values = _extract(dic, [], f"@{attr}", regex=regex)
        for value in values:
            parent='root'
            if value[2]:
                parent=value[2]
            ret_list.append(f"{parent}{value[0]}={value[1]}")

    for node_dic in NODES:
        node, attribute, regex = node_dic.get('node'), node_dic.get('attr'), node_dic.get('regex', False)
        attrs_tuple = _extract(dic, [], node, regex=regex)
        for items in attrs_tuple:
            key, value, parent = items
            for attr in value:
                txt_re = _extract(attr, [], "(#text)", regex=True, parentNode=key)
                if txt_re:
                    txt = txt_re.pop()[1]
                    ret_list.append(f"{parent}[{key}@{attr.get(attribute)}={txt}]")

    if not ret_list:
        return None

    return " ".join(ret_list)


def _extract(obj, arr, key, regex=False, parentNode=None):
    """Recursively search for values of key in JSON tree."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == key:
                arr.append((k,v,parentNode))
            elif regex and re.search(key, k):
                is_match = re.search(key, k)
                if is_match:
                    groups = is_match.groups()
                    for group in groups:
                        arr.append((group,v,parentNode))
            elif isinstance(v, (dict, list)):
                _extract(v, arr, key, regex, k)
    elif isinstance(obj, list):
        for item in obj:
            _extract(item, arr, key, regex, parentNode)
    return arr


t = tail.Tail(FILE_MONITORED)
t.register_callback(print_line)
t.follow(s=int(DELAY))