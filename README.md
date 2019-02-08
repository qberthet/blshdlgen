# BLSHDLgen

VHDL implementation of the **BLS signature scheme** and associated test scripts.

## Dependencies

Tested on linux (ubuntu 16.04)

#### Required packages:

* Vivado : https://www.xilinx.com/products/design-tools/vivado.html
	tested with version 2018.2

* SageMath : http://www.sagemath.org/
	tested with versions 8.3, 8.4, 8.5

* pysha3 : https://pypi.org/project/pysha3/
	tested with version 1.0.2
	Install for sage, run from sage folder:
	```sh
	./sage --python -m easy_install pysha3
	```
## Usage
The script expect two argument to specify the domaine parameter to use and the entity to test:
```sh
./BLSHDLgen.py <domain parameter name> <entity id>
```
When run without argument, a list of the available domain parameter and entity is displayed.

Example to test and synthesize one entity:

```sh
./BLSHDLgen.py CURVE128 field/fp_divider
```
The "all" key word is accepted for both arguments. To run all tests (all domain parameters x all entities):
```sh
./BLSHDLgen.py all all
```