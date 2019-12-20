import os
import random
import string
import subprocess

import csv
import qrcode
from PIL import Image, ImageDraw, ImageFont

def make_qr(data):
    qr = qrcode.QRCode(
        box_size=15,
        border=2,
    )
    qr.add_data(data)
    qr.make(fit=True)
    return qr.make_image(fill_color="black", back_color="white")

def make_qr_with_text(text, data):
    text_space = 40
    
    img = make_qr(data)
    target_size = (img.size[0], img.size[1] + text_space)
    target_img = Image.new('RGBA', target_size, (255,255,255,0))
    
    draw = ImageDraw.Draw(target_img)
    
    text_font = ImageFont.truetype("arial.ttf", 30)
    text_size = draw.textsize(text, font=text_font)
    text_origin = [(img.size[0] / 2) - (text_size[0] / 2), img.size[1]]
    
    draw.rectangle([(0, 0), target_size], 'white')
    target_img.paste(img, [0,0])
    draw.text(text_origin, text, 'black', font=text_font)
    
    return target_img

def main():
    output_dir = 'output'
    if not os.path.isdir(output_dir):
        os.mkdir(output_dir)

    # Generate QR Codes
    output_files = []
    with open(os.path.join(output_dir, 'aCodes.csv'), 'w') as csv_file:
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(['#','Data'])

        for i in range(0, 600):
            prefix = "NITRR{0:03d}".format(i + 1)
            data = prefix + '_' + ''.join(random.choices(string.ascii_uppercase + string.ascii_lowercase + string.digits, k=6))

            file_name = '{0}.png'.format(data)
            img = make_qr_with_text(prefix, data)
            img.save(os.path.join(output_dir, file_name))
            csv_writer.writerow([prefix, data])
            output_files.append(file_name)

    # Generate TIF and PDF
    result = subprocess.run(['convert', 'output/*.png', 'output/aCodes.tif'])
    if result.returncode != 0:
        print('Unable to generate tif')
        exit(1)
    result = subprocess.run(['montage', 'output/aCodes.tif', '-tile', '11x14', '-geometry', '+10+10', '-page', 'A3', 'output/aCodes.pdf'])
    if result.returncode != 0:
        print('Unable to generate pdf')
        exit(1)

if __name__ == '__main__':
    main()

