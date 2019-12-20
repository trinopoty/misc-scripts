import os
import re

def main():
    y_re = re.compile('^(?P<y>[0-9]+).png$')
    for z in os.listdir():
        if not os.path.isdir(z):
            continue
        
        z_dir = z
        z_val = int(z)
        
        for x in os.listdir(z_dir):
            x_dir = os.path.join(z_dir, x)
            x_val = int(x)
            
            for y in os.listdir(x_dir):
                y_file = os.path.join(x_dir, y)
                y_val = int(y_re.match(y).group('y'))
                y_val = (2 ** z_val) - y_val - 1
                os.rename(y_file, os.path.join(x_dir, '{0}.png'.format(y_val)))

if __name__ == '__main__':
    main()

