import base64
import hashlib
import io
import logging
import os.path
from typing import Optional
from urllib.parse import parse_qs

import pillow_avif
import requests
from PIL import Image, ImageOps


LOGGER = logging.getLogger('CfImageResize')


def parse_headers(origin_headers):
    headers = {}
    for k in origin_headers:
        origin_header = origin_headers[k][0]
        headers[k] = origin_header['value']
    return headers


def fetch_origin_resource(origin_request: dict) -> Optional[tuple[str, requests.Response]]:
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
        LOGGER.info("[fetch_origin_resource] Unsupported origin")
        return None

    LOGGER.info("[fetch_origin_resource] Fetching %s", url)

    response = requests.get(url, headers=headers, timeout=10)
    if response.status_code == 200 and response.headers['content-type'] in ['image/png', 'image/jpeg']:
        LOGGER.info("[fetch_origin_resource] Fetched %s [Status=%s]", url, str(response.status_code))

        return url, response,

    return None


def get_size(query) -> Optional[tuple]:
    query = parse_qs(query)
    width = None
    height = None
    if 'width' in query and len(query['width']) > 0:
        width = int(query['width'][0])
    if 'height' in query and len(query['height']) > 0:
        height = int(query['height'][0])
    return (width, height,) if width is not None or height is not None else None


def resize_image(image_bytes, size) -> bytes:
    LOGGER.info("[resize_image] Resizing to %s", size)

    image = Image.open(io.BytesIO(image_bytes))
    image = ImageOps.exif_transpose(image)

    image_w, image_h = image.size
    thumb_w = size[0] if size[0] is not None else image_w
    thumb_h = size[1] if size[1] is not None else image_h

    image.thumbnail((thumb_w, thumb_h,))
    output_bytes = io.BytesIO()

    if image.mode != 'RGB':
        image = image.convert('RGB')

    image.save(output_bytes, format='PNG')
    return output_bytes.getvalue()


def optimize_image(image_bytes, accept_webp, accept_avif) -> tuple[str, bytes]:
    LOGGER.info("[resize_image] Optimizing image [accept_webp=%s, accept_avif=%s]", accept_webp, accept_avif)

    image = Image.open(io.BytesIO(image_bytes))
    image = ImageOps.exif_transpose(image)

    output_bytes = io.BytesIO()

    if image.mode != 'RGB':
        image = image.convert('RGB')

    if accept_avif:
        try:
            image.save(output_bytes, format='AVIF')
            return 'image/avif', output_bytes.getvalue()
        except Exception as _:
            pass

    if accept_webp:
        try:
            image.save(output_bytes, format='WEBP')
            return 'image/webp', output_bytes.getvalue()
        except Exception as _:
            pass

    image.save(output_bytes, format='PNG', optimize=True)
    return 'image/png', output_bytes.getvalue()


def build_response(response, content, content_type):
    LOGGER.info("[build_response] Response Code=%s, Content Length=%s, Content Type=%s",
                response.status_code, len(content), content_type)

    content_hash = '"{0}"'.format(hashlib.md5(content).hexdigest())
    content = base64.b64encode(content).decode()

    headers = {
        'etag': [{
            'key': 'ETag',
            'value': content_hash,
        }],
        'content-type': [{
            'key': 'Content-Type',
            'value': content_type,
        }]
    }

    return {
        'bodyEncoding': 'base64',
        'body': content,
        'status': response.status_code,
        'statusDescription': response.reason,
        'headers': headers
    }


def lambda_handler(event, context):
    LOGGER.setLevel(logging.WARNING)

    LOGGER.info("Processing request: %s", event)

    if event['Records'] and len(event['Records']) > 0:
        record = event['Records'][0]
        if 'cf' in record and 'request' in record['cf'] and record['cf']['request'] is not None:
            origin_request = record['cf']['request']

            accept_webp = False
            accept_avif = False

            headers = parse_headers(origin_request['headers'])
            if 'accept' in headers:
                accept_header = headers['accept'].split(',')
                accept_webp = 'image/webp' in accept_header
                accept_avif = 'image/avif' in accept_header

            try:
                size = get_size(origin_request['querystring'])
            except:
                size = None

            file_ext = os.path.splitext(origin_request['uri'])

            if origin_request['method'].upper() != 'GET':
                return origin_request

            if len(file_ext) != 2 or file_ext[1].lower() not in ['.png', '.jpg', '.jpeg', '.jfif']:
                return origin_request

            if size is None and not accept_webp and not accept_avif:
                return origin_request

            try:
                origin_url, origin_response = fetch_origin_resource(origin_request)
            except Exception as _:
                return {
                    'bodyEncoding': 'text',
                    'body': 'Gateway Timed Out',
                    'status': 504,
                    'statusDescription': 'Gateway Timeout',
                    'headers': {}
                }

            if origin_response is None:
                return origin_request

            # Resize image if needed

            response_content = origin_response.content

            if size is not None:
                try:
                    response_content = resize_image(response_content, size)
                except Exception as _:
                    LOGGER.exception('Unable to process image: %s', origin_url)

            if len(response_content) > 1000000:
                LOGGER.warning("Returning original image because response is too large")
                return origin_request

            # Optimize image if supported

            try:
                content_type, response_content = optimize_image(response_content, accept_webp, accept_avif)
            except Exception as _:
                LOGGER.exception('Unable to optimize image: %s', origin_url)

                content_type = headers['content-type'] if 'content-type' in headers else 'application/octet-stream'

            if len(response_content) > 1000000:
                LOGGER.warning("Returning original image because response is too large")
                return origin_request

            return build_response(origin_response, response_content, content_type)

    return None
