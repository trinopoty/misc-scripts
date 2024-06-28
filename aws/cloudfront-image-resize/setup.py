from distutils.core import setup

setup(name='Cf Image Resize',
      version='1.0',
      description='Dynamically resize image on CloudFront edge',
      author='Trinopoty Biswas',
      author_email='connect@trinopoty.me',
      packages=['.'],
      install_requires=[
          'requests==2.31.0',
          'Pillow==10.2.0',
          'pillow-avif-plugin==1.4.3',
      ])
