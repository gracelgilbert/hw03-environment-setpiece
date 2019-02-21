# Grace Gilbert (gracegi), Environment Setpiece
## Demo Link
https://gracelgilbert.github.io/hw03-environment-setpiece/
![](teacupFinal.png)
## Inspiration
![](3056592-VFMZOWIY-7.jpg)
I liked the composition of this teacup scene, and I liked the saturated lighting, which are elements I used as indpiration in my project.
## External Resources
- For all of my SDFs, I referenced code from Inigo Quielez's website:
http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
- To get soft shadows, I referenced Inigo Quielez's site again:
https://iquilezles.org/www/articles/rmshadows/rmshadows.htm
- I referenced Adam's subsurface example code to achieve the subsurface effect

## Implementation
### Geometry
#### Sugar Cubes
The base geometry of the sugar cubes is an SDF rounded box with a rounding parameter of 0.1. Layered onto this base geometry is a 3D worley noise displacement along the normals ot the box.  The worley noise is densely packed to give the sense of little sugar crystals. The value obtained from the noise is raised to a power of 0.3 to give the bumps more defined peaks. Overall, the normal offset function is the following:

0.04 * pow(computeWorley3D(p.x, p.y, p.z, 200.0, 200.0, 200.0), 0.3)
#### Teacup and Saucer
#### Spoon
#### Table

### Materials
#### Wood
#### Sugar
#### Metal
#### porcelain
#### Wall

### Lighting

### Post Process Elements
