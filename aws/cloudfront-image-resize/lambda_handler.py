import base64
import hashlib
import io
import json
import re
from urllib.parse import parse_qs

import requests
from PIL import Image


whitelisted_headers = [
    'last-modified',
    'cache-control',
    'content-type',
    'etag',
]


def get_size(query):
    query = parse_qs(query)
    width = None
    height = None
    if 'width' in query and len(query['width']) > 0:
        width = int(query['width'][0])
    if 'height' in query and len(query['height']) > 0:
        height = int(query['height'][0])
    return (width, height,) if width is not None or height is not None else None


def resize_image(image_bytes, size):
    image = Image.open(io.BytesIO(image_bytes))

    image_w, image_h = image.size
    thumb_w = size[0] if size[0] is not None else image_w
    thumb_h = size[1] if size[1] is not None else image_h

    image.thumbnail((thumb_w, thumb_h,))
    output_bytes = io.BytesIO()
    image.save(output_bytes, format='PNG')
    return output_bytes.getvalue()


def parse_headers(origin_headers):
    headers = {}
    for k in origin_headers:
        origin_header = origin_headers[k][0]
        headers[k] = origin_header['value']
    return headers


def get_origin_domain(origin):
    for k in origin:
        item = origin[k]
        if 'domainName' in item:
            return item['domainName']
    return None


def build_response(response, content, success):
    content_length = len(content)
    content_hash = '"{0}"'.format(hashlib.md5(content).hexdigest())
    content = base64.b64encode(content).decode()
    
    headers = {}
    for k in response.headers:
        if k.lower() in whitelisted_headers:
            headers[k.lower()] = [{
                'value': response.headers[k],
            }]
    
    if success:
        headers['etag'] = [{
            'key': 'ETag',
            'value': content_hash,
        }]
        headers['content-type'] = [{
            'key': 'Content-Type',
            'value': 'image/png',
        }]
    
    return {
        'bodyEncoding': 'base64',
        'body': content,
        'status': response.status_code,
        'statusDescription': response.reason,
        'headers': headers
    }


def lambda_handler(event, context):
    if event['Records'] and len(event['Records']) > 0:
        record = event['Records'][0]
        if 'cf' in record and 'request' in record['cf'] and record['cf']['request'] is not None:
            origin_request = record['cf']['request']

            try:
                size = get_size(origin_request['querystring'])
            except:
                size = None

            if origin_request['method'].upper() == 'GET' and size is not None and (origin_request['uri'].endswith('.png') or origin_request['uri'].endswith('.jpg') or origin_request['uri'].endswith('.jpeg')):
                headers = parse_headers(origin_request['headers'])
                query = '?{0}'.format(origin_request['querystring']) if len(origin_request['querystring']) > 0 else ''
                
                if 'accept-encoding' in headers:
                    del headers['accept-encoding']
                
                if 'custom' in origin_request['origin']:
                    headers['host'] = origin_request['origin']['custom']['domainName']
                    origin_headers = parse_headers(origin_request['origin']['custom']['customHeaders'])
                    headers = {**headers, **origin_headers}

                    url = '{0}://{1}:{2}{3}{4}{5}'.format(
                        origin_request['origin']['custom']['protocol'],
                        origin_request['origin']['custom']['domainName'],
                        origin_request['origin']['custom']['port'],
                        origin_request['origin']['custom']['path'],
                        origin_request['uri'],
                        query)
                elif 's3' in origin_request['origin']:
                    headers['host'] = origin_request['origin']['s3']['domainName']
                    origin_headers = parse_headers(origin_request['origin']['s3']['customHeaders'])
                    headers = {**headers, **origin_headers}

                    url = '{0}://{1}:{2}{3}{4}{5}'.format(
                        'https',
                        origin_request['origin']['s3']['domainName'],
                        443,
                        origin_request['origin']['s3']['path'],
                        origin_request['uri'],
                        query)
                else:
                    return origin_request
                
                try:
                    response = requests.get(url, headers=headers, timeout=30)
                    if response.status_code == 200 and response.headers['content-type'] in ['image/png', 'image/jpeg']:
                        thumbnail = resize_image(response.content, size)
                        return build_response(response, thumbnail, True)
                    else:
                        return build_response(response, response.content, False)
                except requests.exceptions.Timeout as e:
                    return {
                        'bodyEncoding': 'text',
                        'body': 'Gateway Timed Out',
                        'status': 504,
                        'statusDescription': 'Gateway Timeout',
                        'headers': {}
                    }
            else:
                if 'host' in origin_request['headers']:
                    origin_request['headers']['host'][0]['value'] = get_origin_domain(origin_request['origin'])

            return origin_request

    return None

