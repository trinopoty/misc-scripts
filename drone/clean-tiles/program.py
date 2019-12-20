import os
import sys
import multiprocessing as mp

import imageio
import numpy

def process_file(x_file):
    im = imageio.imread(x_file)

    check_arr = numpy.zeros(4).astype(int)
    for row in im:
        for col in row:
            numpy.bitwise_or(check_arr, col, check_arr)

    if check_arr[3] == 0:
        os.remove(x_file)

def main():
    if len(sys.argv) != 2:
        print('Directory not provided.')
        sys.exit(1)
    
    input_dir = sys.argv[1]
    if not os.path.isdir(input_dir):
        print('Provided path is not a directory.')
        sys.exit(1)
    
    files_arr = []
    for z in os.listdir(input_dir):
        z_dir = os.path.join(input_dir, z)
        if not os.path.isdir(z_dir):
            continue
        
        for y in os.listdir(z_dir):
            y_dir = os.path.join(z_dir, y)
            if not os.path.isdir(y_dir):
                continue

            for x in os.listdir(y_dir):
                x_file = os.path.join(y_dir, x)
                if not os.path.isfile(x_file):
                    continue
                if not x_file.endswith('.png'):
                    continue

                files_arr.append(x_file)
    
    cpu_count = mp.cpu_count()
    if cpu_count > 1:
        cpu_count = cpu_count - 1
    pool = mp.Pool(cpu_count)
    pool.map(process_file, files_arr)

if __name__ == '__main__':
    main()
