# resize an image using the PIL image library
# free from:  http://www.pythonware.com/products/pil/index.htm
# tested with Python24        vegaseat     11oct2005

import Image

# open an image file (.bmp,.jpg,.png,.gif) you have in the working folder
imageFile = "../emot-xd.gif"

im1 = Image.open(imageFile)

# adjust width and height to your needs
width = 30
height = 30
# use one of these filter options to resize the image
im2 = im1.resize((width, height), Image.NEAREST)      # use nearest neighbour

im2.save(imageFile + "@2x.gif")
