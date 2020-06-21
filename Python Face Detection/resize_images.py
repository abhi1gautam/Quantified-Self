import os
import argparse
from PIL import Image

DEFAULT_RESIZE_FACTOR = 10


def resize_image(input_dir, infile, output_dir="resized", resize_factor= DEFAULT_RESIZE_FACTOR):
    outfile = os.path.splitext(infile)[0] + "_resized"
    extension = os.path.splitext(infile)[1]

    try:
        img = Image.open(input_dir + '/' + infile)

        size= (int(img.width/resize_factor), int(img.height/resize_factor))

        img = img.resize((size[0], size[1]), Image.LANCZOS)

        new_file = output_dir + "/" + outfile + extension
        img.save(new_file)
    except IOError:
        print("unable to resize image {}".format(infile))


if __name__ == "__main__":
    dir = os.getcwd()

    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input_dir', help='Full Input Path')
    parser.add_argument('-o', '--output_dir', help='Full Output Path')

    parser.add_argument('-r', '--resize_factor', help='Resize factor')

    args = parser.parse_args()

    if args.input_dir:
        input_dir = args.input_dir
    else:
        input_dir = dir + '/images'

    if args.output_dir:
        output_dir = args.output_dir
    else:
        output_dir = dir + '/resized'

    if not os.path.exists(os.path.join(dir, output_dir)):
        os.mkdir(output_dir)

    if args.resize_factor:
        resize_factor = int(args.resize_factor)
    else:
        resize_factor = DEFAULT_RESIZE_FACTOR

    try:
        for file in os.listdir(input_dir):
            resize_image(input_dir, file, output_dir, resize_factor)
    except OSError:
        print('file not found')