#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const float epsilon = 0.01;
const float pi = 3.1415926535;
const float AO_DIST = 0.085;
const float DISTORTION = 0.2;
// The higher GLOW is, the smaller the glow of the subsurface scattering
const float GLOW = 6.0;
// The higher the BSSRDF_SCALE, the brighter the scattered light
const float BSSRDF_SCALE = 3.0;
// Boost the shadowed areas in the subsurface glow with this
const float AMBIENT = 0.0;
const float FIVETAP_K = 2.0;

// Noise functions:
float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

float random1( vec3 p , vec3 seed) {
  return fract(sin(dot(p + seed, vec3(987.654, 123.456, 531.975))) * 85734.3545);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed, vec2(311.7, 127.1)), dot(p + seed, vec2(269.5, 183.3)))) * 85734.3545);
}

float interpNoise2d(float x, float y) {
  float intX = floor(x);
  float fractX = fract(x);
  float intY = floor(y);
  float fractY = fract(y);

  float v1 = random1(vec2(intX, intY), vec2(1.f, 1.f));
  float v2 = random1(vec2(intX + 1.f, intY), vec2(1.f, 1.f));
  float v3 = random1(vec2(intX, intY + 1.f), vec2(1.f, 1.f));
  float v4 = random1(vec2(intX + 1.f, intY + 1.f), vec2(1.f, 1.f));

  float i1 = mix(v1, v2, fractX);
  float i2 = mix(v3, v4, fractX);
  return mix(i1, i2, fractY);
  return 2.0;

}


float interpNoise3d(float x, float y, float z) {
  float intX = floor(x);
  float fractX = fract(x);
  float intY = floor(y);
  float fractY = fract(y);
  float intZ = floor(z);
  float fractZ = fract(z);

  float v1 = random1(vec3(intX, intY, intZ), vec3(1.f, 1.f, 1.f));
  float v2 = random1(vec3(intX, intY, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v3 = random1(vec3(intX + 1.0, intY, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v4 = random1(vec3(intX + 1.0, intY, intZ), vec3(1.f, 1.f, 1.f));
  float v5 = random1(vec3(intX, intY + 1.0, intZ), vec3(1.f, 1.f, 1.f));
  float v6 = random1(vec3(intX, intY + 1.0, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v7 = random1(vec3(intX + 1.0, intY + 1.0, intZ + 1.0), vec3(1.f, 1.f, 1.f));
  float v8 = random1(vec3(intX + 1.0, intY + 1.0, intZ), vec3(1.f, 1.f, 1.f));

  float i1 = mix(v2, v3, fractX);
  float i2 = mix(v1, v4, fractX);
  float i3 = mix(v6, v7, fractX);
  float i4 = mix(v5, v8, fractX);

  float j1 = mix(i4, i3, fractZ);
  float j2 = mix(i2, i1, fractZ);

  return mix(j2, j1, fractY);

}

// Worley and FBM
float computeWorley(float x, float y, float numRows, float numCols) {
    float xPos = x * float(numCols) / 20.f;
    float yPos = y * float(numRows) / 20.f;

    float minDist = 60.f;
    vec2 minVec = vec2(0.f, 0.f);

    for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
            vec2 currGrid = vec2(floor(float(xPos)) + float(i), floor(float(yPos)) + float(j));
            vec2 currNoise = currGrid + random2(currGrid, vec2(2.0, 1.0));
            float currDist = distance(vec2(xPos, yPos), currNoise);
            if (currDist <= minDist) {
                minDist = currDist;
                minVec = currNoise;
            }
        }
    }
    return minDist;
    // return 2.0;
}

float computeWorley3D(float x, float y, float z, float numRows, float numCols, float numZ) {
    float xPos = x * float(numCols) / 20.f;
    float yPos = y * float(numRows) / 20.f;
    float zPos = z * float(numZ) / 20.f;


    float minDist = 60.f;
    vec3 minVec = vec3(0.f, 0.f, 0.f);

    for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
            for (int k = -1; k < 2; k++) {
              vec3 currGrid = vec3(floor(float(xPos)) + float(i), floor(float(yPos)) + float(j), floor(float(zPos)) + float(k));
              vec3 currNoise = currGrid + vec3(random1(currGrid, vec3(2.0, 1.0, 3.0)), random1(currGrid, vec3(1.0, 2.0, 7.0)), random1(currGrid, vec3(5.0, 4.0, 8.0))); // GET 3D random
              float currDist = distance(vec3(xPos, yPos, zPos), currNoise);
              if (currDist <= minDist) {
                  minDist = currDist;
                  minVec = currNoise;
              }
            }

        }
    }
    return minDist;
    // return 2.0;
}

float fbm(float x, float y, float height, float xScale, float yScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 3;
  float freq = 2.0;
  float amp = 1.0;
  for (int i = 0; i < octaves; i++) {
    // total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    freq *= 2.0;
    amp *= persistence;
  }
  return height * total;
}

float fbm3D(float x, float y, float z, float height, float xScale, float yScale, float zScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 3;
  float freq = 2.0;
  float amp = 1.0;
  for (int i = 0; i < octaves; i++) {
    // total += interpNoise2d( (x / xScale) * freq, (y / yScale) * freq) * amp;
    total += interpNoise3d( (x / xScale) * freq, (y / yScale) * freq, (z / zScale) * freq) * amp;
    freq *= 2.0;
    amp *= persistence;
  }
  return height * total;
}
// SDF Combinations
float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}
float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); 
}

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h); 
}

float opUnion( float d1, float d2 ) {  
  return min(d1,d2); 
}

float opSubtraction( float d1, float d2 ) { 
  return max(-d1,d2); 
}

float opIntersection( float d1, float d2 ) { 
  return max(d1,d2); 
}

// SDFs:
float sphereSDF( vec3 p, float radius ) {
  return length(p)-radius;
}

float sdPlane( vec3 p, vec4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

	float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float sdRoundedCylinder( vec3 p, float ra, float rb, float h )
{
    vec2 d = vec2( length(p.xz)-2.0*ra+rb, abs(p.y) - h );
    return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}
float sdCappedCone( in vec3 p, in float h, in float r1, in float r2 )
{
    vec2 q = vec2( length(p.xz), p.y );
    
    vec2 k1 = vec2(r2,h);
    vec2 k2 = vec2(r2-r1,2.0*h);
    vec2 ca = vec2(q.x-min(q.x,(q.y < 0.0)?r1:r2), abs(q.y)-h);
    vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot(k2, k2), 0.0, 1.0 );
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s*sqrt( min(dot(ca, ca),dot(cb, cb)) );
}
vec3 getSphereNormal(vec3 p, float t) {
  return normalize(vec3(  sphereSDF(vec3(p[0] + 0.001, p[1], p[2]), t) - sphereSDF(vec3(p[0] - 0.001, p[1], p[2]), t),
                          sphereSDF(vec3(p[0], p[1] + 0.001, p[2]), t) - sphereSDF(vec3(p[0], p[1] - 0.001, p[2]), t),
                          sphereSDF(vec3(p[0], p[1], p[2] + 0.001), t) - sphereSDF(vec3(p[0], p[1], p[2] - 0.001), t)
                       ));
}

float sdCappedCylinder( vec3 p, vec2 h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// float sdRoundBox( vec3 p, vec3 b, float r )
// {
//   vec3 d = abs(p) - b;
//   return length(max(d,0.0)) - r
//          + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
// }

	float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 d = abs(p) - b;
  float val =  length(max(d,0.0))
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
  return val - r;
}


vec3 castRay(vec3 eye) {
  float a = fs_Pos.x;
  float b = fs_Pos.y;

  vec3 forward = normalize(u_Ref - eye);
  vec3 right = normalize(cross(forward, u_Up));

  vec3 v = (u_Up) * tan(45.0 / 2.0);
  vec3 h = right * (u_Dimensions.x / u_Dimensions.y) * tan(45.0 / 2.0);
  vec3 point = forward + (a * h) + (b * v);

  return normalize(point);
}

float tableSDF(vec3 p) {
  // float zFreq = 0.9 + 0.08 * (sin(p.x / 5.0 + 2.0) + sin(p.x / 4.0 + 9.0) + cos(p.z / 3.0));
  // float tVal = 1.0 - (1.0 * fbm(p.x, p.z, 1.0, 9.0, zFreq));

  vec3 tableTranslate = vec3(0.0, 1.2, 0.0);;
  // p.y -= 0.05 * tVal;

  return sdBox(p + tableTranslate, vec3(20.0, 0.1, 10.0));

}

float saucerSDF(vec3 p) {
  vec3 pTranslate = vec3(2.6, 0.6, 0.0);
  vec3 cutoutTranslate = vec3(0.0, -0.1, 0.0);

  float baseConeDist = sdCappedCone(p + pTranslate, 0.3, 2.1, 3.5);
  float innerCutoutConeDist = sdCappedCone(p + pTranslate + cutoutTranslate, 0.3, 1.59, 3.1);

  float baseSaucerDist = opSmoothSubtraction(innerCutoutConeDist, baseConeDist, 0.15);

  vec3 topTorusTranslate = vec3(0.0, -0.25, 0.0);
  vec3 topTorusScale = vec3(1.0, 1.6, 1.0);
  float topTorusDist = sdTorus((p + pTranslate + topTorusTranslate) * topTorusScale, vec2(3.48, 0.07));
    
  vec3 bottomTorusTranslate = vec3(0.0, 0.46, 0.0);
  vec3 bottomTorusScale = vec3(1.0, 3.0, 1.0);
  float bottomTorusDist = sdTorus((p + pTranslate + bottomTorusTranslate) * bottomTorusScale, vec2(1.55, 0.35));


  return opSmoothUnion(opSmoothUnion(topTorusDist, baseSaucerDist, 0.25), bottomTorusDist, 0.6);

  // vec3 pScale = vec3(1.0, 3.0, 1.0);
  // return sdTorus(p * pScale, vec2(2.0, 1.0));
}


vec3 getSaucerNormal(vec3 p) {
  return normalize(vec3(  saucerSDF(vec3(p[0] + 0.001, p[1], p[2])) - saucerSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          saucerSDF(vec3(p[0], p[1] + 0.001, p[2])) - saucerSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          saucerSDF(vec3(p[0], p[1], p[2] + 0.001)) - saucerSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}

float cupSDF(vec3 p) {
  vec3 pTranslate = vec3(2.6, 0.45, 0.0);
  p += pTranslate;
  vec3 baseConeTransform = vec3(0.0, 0.1, 0.0);
  float baseConeDist = sdCappedCone(p + baseConeTransform, 0.3, 1.5, 0.7);

  vec3 sphereScale = vec3(0.73, 1.05, 0.73);
  vec3 sphereTranslate = vec3(0.0, -0.8, 0.0); 
  float baseSphereDist = sphereSDF(p * sphereScale + sphereTranslate, 1.1);

  vec3 subtractBoxScale = vec3(0.55, 0.35, 0.55);
  vec3 subtractBoxTranslate = vec3(0.0, -1.38, 0.0); 
  float subtractBoxDist = sdBox(p * subtractBoxScale + subtractBoxTranslate, vec3(1.0, 1.0, 1.0));
  baseSphereDist = opSubtraction(subtractBoxDist, baseSphereDist);

  // vec3 cupCylScale = vec3(0.4, 0.8, 0.4);
  vec3 cupConeScale = vec3(1.0, 1.0, 1.0);
  vec3 cupConeTranslate = vec3(0.0, -1.8, 0.0);

  // vec3 cupCylTranslate = vec3(0.0, -1.4, 0.0);
  // float cupCylDist = sdCappedCylinder(p * cupCylScale + cupCylTranslate, vec2(1.0, 1.0));
  float cupConeDist = sdCappedCone(p * cupConeScale + cupConeTranslate, 1.2, 1.8, 2.0);

  vec3 torusTranslate = vec3(0.0, -1.2, 0.0);
  vec3 torusScale = vec3(1.0, 0.8, 1.0);
  float cutoutTorus = sdTorus(p * torusScale + torusTranslate, vec2(5.3, 3.5));
  cupConeDist = opSmoothSubtraction(cutoutTorus, cupConeDist, 0.1);

  vec3 cupConeSubtractScale = vec3(1.0, 1.0, 1.0);
  vec3 cupConeSubtractTranslate = vec3(0.0, -1.8, 0.0);
  // float cupCylSubtractDist = sdCappedCylinder(p * cupCylSubtractScale + cupCylSubtractTranslate, vec2(1.0, 1.0));
  float cupConeSubtractDist = sdCappedCone(p * cupConeSubtractScale + cupConeSubtractTranslate, 1.3, 1.6, 1.8);

  
  vec3 torus2Translate = vec3(0.0, -1.0, 0.0);
  vec3 torus2Scale = vec3(1.0, 0.77, 1.0);
  float cutout2Torus = sdTorus(p * torusScale + torusTranslate, vec2(5.3, 3.5));
  cupConeSubtractDist = opSubtraction(cutout2Torus, cupConeSubtractDist);

  cupConeDist = opSubtraction(cupConeSubtractDist, cupConeDist);
  return opSmoothUnion(opSmoothUnion(baseConeDist, baseSphereDist, 0.2), cupConeDist, 0.3);
}

float sugarCubesFlatSDF(vec3 p) {
  vec3 cube1Translate = vec3(-5.95, 0.7, -0.9);
  vec3 cube1Scale = vec3(1.0, 1.0, 1.0);

  float cube1Theta = pi / 8.0;
  mat3 cube1Rotation   = mat3(vec3(cos(cube1Theta), 0, sin(cube1Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube1Theta), 0, cos(cube1Theta))
                         );
  float cube1Dist =  sdRoundBox((cube1Scale * p + cube1Translate) * cube1Rotation, vec3(0.6, 0.35, 0.38), 0.1);

  vec3 cube2Translate = vec3(-4.4, 0.7, -0.3);
  vec3 cube2Scale = vec3(1.0, 1.0, 1.0);

  float cube2Theta = -pi / 7.0;
  mat3 cube2Rotation   = mat3(vec3(cos(cube2Theta), 0, sin(cube2Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube2Theta), 0, cos(cube2Theta))
                         );
  float cube2Dist =  sdRoundBox((cube2Scale * p + cube2Translate) * cube2Rotation, vec3(0.55, 0.35, 0.38), 0.1);

  vec3 cube3Translate = vec3(-5.0, -0.16, -0.3);
  vec3 cube3Scale = vec3(1.0, 1.0, 1.0);

  float cube3Theta = pi / 30.0;
  mat3 cube3Rotation   = mat3(vec3(cos(cube3Theta), 0, sin(cube3Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube3Theta), 0, cos(cube3Theta))
                         );
  float cube3Dist =  sdRoundBox((cube3Scale * p + cube3Translate) * cube3Rotation, vec3(0.48, 0.32, 0.38), 0.08);

  return opUnion(opUnion(cube1Dist, cube2Dist), cube3Dist);

}
vec3 getSugarCubeFlatNormal(vec3 p) {
  return normalize(vec3(  sugarCubesFlatSDF(vec3(p[0] + 0.001, p[1], p[2])) - sugarCubesFlatSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          sugarCubesFlatSDF(vec3(p[0], p[1] + 0.001, p[2])) - sugarCubesFlatSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          sugarCubesFlatSDF(vec3(p[0], p[1], p[2] + 0.001)) - sugarCubesFlatSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}
float sugarCubesSDF(vec3 p) {
  // float sugarCubeBump = fbm3D(p.x, p.y, p.z, 0.05, 0.2, 0.2, 0.2);
  // float sugarCubeBump = 0.02 * pow(computeWorley3D(p.x, p.y, p.z, 50.0, 50.0, 200.0), 0.3);
  // p += sugarCubeBump * getSugarCubeFlatNormal(p);

  vec3 cube1Translate = vec3(-5.95, 0.7, -0.9);
  vec3 cube1Scale = vec3(1.0, 1.0, 1.0);

  float cube1Theta = pi / 8.0;
  mat3 cube1Rotation   = mat3(vec3(cos(cube1Theta), 0, sin(cube1Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube1Theta), 0, cos(cube1Theta))
                         );
  float cube1Dist =  sdRoundBox((cube1Scale * p + cube1Translate) * cube1Rotation, vec3(0.6, 0.35, 0.38), 0.1);

  vec3 cube2Translate = vec3(-4.4, 0.7, -0.3);
  vec3 cube2Scale = vec3(1.0, 1.0, 1.0);

  float cube2Theta = -pi / 7.0;
  mat3 cube2Rotation   = mat3(vec3(cos(cube2Theta), 0, sin(cube2Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube2Theta), 0, cos(cube2Theta))
                         );
  float cube2Dist =  sdRoundBox((cube2Scale * p + cube2Translate) * cube2Rotation, vec3(0.55, 0.35, 0.38), 0.1);

  vec3 cube3Translate = vec3(-5.0, -0.16, -0.3);
  vec3 cube3Scale = vec3(1.0, 1.0, 1.0);

  float cube3Theta = pi / 30.0;
  mat3 cube3Rotation   = mat3(vec3(cos(cube3Theta), 0, sin(cube3Theta)),
                         vec3(0, 1, 0),
                         vec3(-sin(cube3Theta), 0, cos(cube3Theta))
                         );
  float cube3Dist =  sdRoundBox((cube3Scale * p + cube3Translate) * cube3Rotation, vec3(0.48, 0.32, 0.38), 0.08);

  return opUnion(opUnion(cube1Dist, cube2Dist), cube3Dist);

}

float spoonSDF(vec3 p) {
  vec3 spoonTranslate = vec3(-0.75, 0.3, 2.5);
  vec3 spoonPostTranslate = vec3(0.04, 0.0, 0.0);
  vec3 spoonScale = vec3(0.25, 0.8, 0.3);
  float spoonTheta = -pi / 6.0;
  mat3 spoonRotationY = mat3(vec3(cos(spoonTheta), 0, sin(spoonTheta)),
                             vec3(0, 1, 0),
                             vec3(-sin(spoonTheta), 0, cos(spoonTheta))
                            );
  float spoonThetaZ = -pi / 9.0;
  mat3 spoonRotationZ = mat3(vec3(cos(spoonThetaZ), sin(spoonThetaZ), 0),
                           vec3(-sin(spoonThetaZ), cos(spoonThetaZ), 0),
                           vec3(0, 0, 1)
                           );
  float spoonMainDist = sphereSDF( ((p + spoonTranslate) * spoonRotationY * spoonRotationZ * spoonScale) + spoonPostTranslate, 0.2);


  vec3 spoonCutoutTranslate = vec3(-0.71, 0.18, 2.48);
  vec3 spoonCutoutScale = vec3(0.25, 0.75, 0.3);
  float spoonCutoutDist = sphereSDF( ((p + spoonCutoutTranslate) * spoonRotationY * spoonRotationZ * spoonCutoutScale) + spoonPostTranslate, 0.21);

  spoonMainDist = opSmoothSubtraction(spoonCutoutDist, spoonMainDist, 0.05);

  vec3 handleTranslate = vec3(-0.81, 0.42, 2.48);
  vec3 handlePostTranslate = vec3(-1.2, -0.03, 0.02);
  vec3 handleScale = vec3(0.45, 1.0, 0.3);

  float handleThetaZ = -pi / 15.0;
  mat3 handleRotationZ = mat3(vec3(cos(handleThetaZ), sin(handleThetaZ), 0),
                           vec3(-sin(handleThetaZ), cos(handleThetaZ), 0),
                           vec3(0, 0, 1)
                           );
  float handleDist = sphereSDF( (((p + handleTranslate) * spoonRotationY * handleRotationZ * handleScale)) + handlePostTranslate, 0.1);

  vec3 connectPostTranslate = vec3(-0.9, 0.3, 0.0);
  vec3 connectScale = vec3(1.0, 1.0, 1.0);
  float connectThetaZ = pi / 40.0;
  mat3 connectRotationZ = mat3(vec3(cos(connectThetaZ), sin(connectThetaZ), 0),
                           vec3(-sin(connectThetaZ), cos(connectThetaZ), 0),
                           vec3(0, 0, 1)
                           );  
  float connectDist = sdBox( (((p + spoonTranslate) * spoonRotationY * connectRotationZ * connectScale)) + connectPostTranslate, vec3(0.3, 0.02, 0.07));

  vec3 connect2PostTranslate = vec3(-1.55, -0.1, 0.0);
  vec3 connect2Scale = vec3(1.0, 1.0, 1.0);
  float connect2ThetaZ = -pi / 13.0;
  mat3 connect2RotationZ = mat3(vec3(cos(connect2ThetaZ), sin(connect2ThetaZ), 0),
                           vec3(-sin(connect2ThetaZ), cos(connect2ThetaZ), 0),
                           vec3(0, 0, 1)
                           );  
  float connect2Dist = sdBox( (((p + spoonTranslate) * spoonRotationY * connect2RotationZ * connect2Scale)) + connect2PostTranslate, vec3(0.3, 0.02, 0.07));
  connectDist = opSmoothUnion(connectDist, connect2Dist, 0.1);



  vec3 connect3PostTranslate = vec3(-2.15, -0.38, 0.0);
  vec3 connect3Scale = vec3(1.0, 1.0, 1.0);
  float connect3ThetaZ = -pi / 8.0;
  mat3 connect3RotationZ = mat3(vec3(cos(connect3ThetaZ), sin(connect3ThetaZ), 0),
                           vec3(-sin(connect3ThetaZ), cos(connect3ThetaZ), 0),
                           vec3(0, 0, 1)
                           );  
  float connect3Dist = sdBox( (((p + spoonTranslate) * spoonRotationY * connect3RotationZ * connect3Scale)) + connect3PostTranslate, vec3(0.3, 0.02, 0.07));
  connectDist = opSmoothUnion(connectDist, connect3Dist, 0.1);

  float spoonDist = opSmoothUnion(opUnion(handleDist, opSmoothSubtraction(spoonCutoutDist, spoonMainDist, 0.05)), connectDist, 0.1);
  // float spoonDist = opSmoothUnion(opSmoothSubtraction(spoonCutoutDist, spoonMainDist, 0.05), connectDist, 0.1);


  return spoonDist;
}

vec3 getSugarCubeNormal(vec3 p) {
  return normalize(vec3(  sugarCubesSDF(vec3(p[0] + 0.001, p[1], p[2])) - sugarCubesSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          sugarCubesSDF(vec3(p[0], p[1] + 0.001, p[2])) - sugarCubesSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          sugarCubesSDF(vec3(p[0], p[1], p[2] + 0.001)) - sugarCubesSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}



vec3 getTableNormal(vec3 p) {

  return normalize(vec3(  tableSDF(vec3(p[0] + 0.001, p[1], p[2])) - tableSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          tableSDF(vec3(p[0], p[1] + 0.001, p[2])) - tableSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          tableSDF(vec3(p[0], p[1], p[2] + 0.001)) - tableSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}

vec3 getCupNormal(vec3 p) {
  return normalize(vec3(  cupSDF(vec3(p[0] + 0.001, p[1], p[2])) - cupSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          cupSDF(vec3(p[0], p[1] + 0.001, p[2])) - cupSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          cupSDF(vec3(p[0], p[1], p[2] + 0.001)) - cupSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}

vec3 getSpoonNormal(vec3 p) {
  return normalize(vec3(  spoonSDF(vec3(p[0] + 0.001, p[1], p[2])) - spoonSDF(vec3(p[0] - 0.001, p[1], p[2])),
                          spoonSDF(vec3(p[0], p[1] + 0.001, p[2])) - spoonSDF(vec3(p[0], p[1] - 0.001, p[2])),
                          spoonSDF(vec3(p[0], p[1], p[2] + 0.001)) - spoonSDF(vec3(p[0], p[1], p[2] - 0.001))
                       ));
}
float sceneSDFnoMat(vec3 p) {

  // return sphereSDF(p, 2.0);

  float saucerDist = saucerSDF(p);
  float tableDist = tableSDF(p);
  float cupDist = cupSDF(p);
  float sugarCubeDist = sugarCubesSDF(p);
  float spoonDist = spoonSDF(p);


  if (saucerDist < tableDist && saucerDist < cupDist && saucerDist < sugarCubeDist && saucerDist < spoonDist) {
    return saucerDist;
  } else if (tableDist < cupDist && tableDist < sugarCubeDist && tableDist < spoonDist){
    return tableDist;
  } else if (cupDist < sugarCubeDist && cupDist < spoonDist) {
    return cupDist;
  } else if (sugarCubeDist < spoonDist) {
    return sugarCubeDist;
  } else {
    return spoonDist;
  }
}

float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    for( float t=mint; t < maxt; )
    {
        float h = sceneSDFnoMat(ro + rd*t);
        if( h<epsilon )
            return 0.0;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}

// float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
// {
//     float res = 1.0;
//     float ph = 1e20;
//     float counter = 0.0;
//     for( float t=mint; t < maxt; )
//     {
//         float h = sceneSDFnoMat(ro + rd*t);
//         if( abs(h)< 0.1 * epsilon ) {
//             return 0.0;
//         }
//         float y = h*h/(2.0*ph);
//         float d = sqrt(h*h-y*y);
//         res = min(res, k*d/max(0.0,t-y));
//         ph = h;
//         t += h;
//         counter ++;
//         if (counter > 50.0) {
//           return res;
//         }
//     }
//     return res;
// }

float fiveTapAO(vec3 p, vec3 n, float k) {
    float aoSum = 0.0;
    for(float i = 0.0; i < 5.0; ++i) {
        float coeff = 1.0 / pow(2.0, i);
        aoSum += coeff * (i * AO_DIST - sceneSDFnoMat(p + n * i * AO_DIST));
    }
    return 1.0 - k * aoSum;
}

float subsurface(vec3 lightDir, vec3 normal, vec3 viewVec, float thickness) {
    vec3 scatteredLightDir = lightDir + normal * DISTORTION;
    float lightReachingEye = pow(clamp(dot(viewVec, -scatteredLightDir), 0.0, 1.0), GLOW) * BSSRDF_SCALE;
    float attenuation = 1.0;
    // #if ATTENUATION
    // attenuation = max(0.0, dot(normal, lightDir) + dot(viewVec, -lightDir));
    // #endif
	float totalLight = attenuation * (lightReachingEye + AMBIENT) * thickness;
    return totalLight;
}


vec4 ceramicMaterial(vec3 normal, vec3 point, vec3 dir) {
  float reflectiveTerm = 0.8 * pow(abs(dot(normalize(normal), normalize(dir))), 15.0);
  // normal.y += 0.8 * fbm3D(point.x, point.y, point.z, 3.0, 2.5, 2.5, 2.5);
  //   normal.x += 0.7* fbm3D(point.x + 2.0, point.y, point.z, 1.0, 3.0, 3.0, 3.0);
    vec3 lightPosition = vec3(3.0, 7.0, -3.0);
    vec4 diffuseColor = vec4(0.95, 0.95, 0.9, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(lightPosition - point));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
    vec3 shadowPoint = point + epsilon * normalize((lightPosition - point));
    // float shadowVal = softshadow(point, normalize(lightPosition - point), 0.1, 3.0, 32.0);
    float shadowVal = 1.0;
    vec3 shadowColor = vec3(0.07, 0.1, 0.15);
            float ao = fiveTapAO(point, normal, 4.0);




    return vec4(ao * shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm * reflectiveTerm * vec3(0.8, 0.6, 1.0)), diffuseColor.a);
        // return vec4((1.0 - shadowVal) * shadowColor + shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm * reflectiveTerm * vec3(0.8, 0.6, 1.0)), diffuseColor.a);

}

vec4 sugarMaterial(vec3 normal, vec3 point, vec3 dir) {
  float reflectiveTerm = 0.8 * pow(abs(dot(normalize(normal), normalize(dir))), 15.0);
  // normal.y += 0.8 * fbm3D(point.x, point.y, point.z, 3.0, 2.5, 2.5, 2.5);
  //   normal.x += 0.7* fbm3D(point.x + 2.0, point.y, point.z, 1.0, 3.0, 3.0, 3.0);
    vec3 lightPosition = vec3(2.0, 7.0, -3.0);
    vec3 light2Position = vec3(-12.0, 10.0, -3.0);
    vec3 light3Position = vec3(0.0, 10.0, 5.0);
    vec3 light1Color = vec3(0.95, 0.9, 1.0);
    vec3 light2Color = vec3(1.0, 0.9, 0.7);
    vec3 light3Color = vec3(1.0, 1.0, 1.0);
    
    vec3 aoLightPosition = vec3(5.8, 0.0, 3.0);


    vec3 baseAlbedo = vec3(0.95, 0.95, 1.0);
    vec4 diffuseColor = vec4(baseAlbedo, 1.0);

    float diffuseTerm = 0.13 * dot(normalize(normal), normalize(lightPosition - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light2Position - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light3Position - point));
    
    float shadowVal1 = softshadow(point, normalize(lightPosition - point), 0.2, 10.0, 12.0) + 0.1;
    float shadowVal2 = softshadow(point, normalize(light2Position - point), 0.2, 10.0, 16.0) + 0.1;
    float shadowVal3 = softshadow(point, normalize(light3Position - point), 0.2, 10.0, 44.0) + 0.1;
   
    float light1Intensity = 0.6 * shadowVal1;
    float light2Intensity = 0.6 * shadowVal2;
    float light3Intensity = 0.1 * shadowVal3;

    // float light1Intensity = 0.6;
    // float light2Intensity = 0.6;
    // float light3Intensity = 0.1;
    vec3 baseColor = diffuseColor.rgb + diffuseTerm;
    float ao = fiveTapAO(point, normal, 5.0);
    // float ao = 1.0;
    float thickness = fiveTapAO(point, dir, 4.0 * FIVETAP_K);
        // return color + vec3(1.0, 0.67, 0.67) * subsurface(light, n, view, thick) * vec3(1.0, 0.88, 0.7);
    vec3 ss = vec3(1.0, 0.87, 0.87) * subsurface(point - aoLightPosition, normal, dir, thickness) * baseColor;

    return vec4(0.4 * ss + ao * baseColor * (light1Intensity * light1Color + light2Intensity * light2Color + light3Intensity * light3Color), diffuseColor.a);
        // return vec4((1.0 - shadowVal) * shadowColor + shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm * reflectiveTerm * vec3(0.8, 0.6, 1.0)), diffuseColor.a);

}

vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

vec3 tableBaseColor(vec3 point) {
  float zFreq = 0.9 + 0.08 * (sin(point.x / 5.0 + 2.0) + sin(point.x / 4.0 + 9.0) + cos(point.z / 3.0));
  float tVal = 1.0 - fract(3.0 * fbm(point.x, point.z, 1.0, 9.0, zFreq));
  float roughness = 0.2 + pow(fbm(point.x, point.z, 1.1, 1.0, 0.09), 1.1);
  float lines = 1.0;
  if (sin(point.z * 4.0) > 0.99) {
    lines = 0.0;
  }
  return lines * roughness * 0.5 * palette(tVal, vec3(0.42,0.25,0.07),vec3(0.3,0.3,0.2),vec3(1.0,1.0,1.0),vec3(0.18,0.16,0.11) );
}


vec4 tableMaterial(vec3 normal, vec3 point, vec3 dir) {

    vec3 lightPosition = vec3(2.0, 7.0, -3.0);
    vec3 light2Position = vec3(-12.0, 10.0, -3.0);
    vec3 light3Position = vec3(0.0, 10.0, 5.0);
    vec3 light1Color = vec3(0.95, 0.9, 1.0);
    vec3 light2Color = vec3(1.0, 0.9, 0.7);
    vec3 light3Color = vec3(1.0, 1.0, 1.0);

    vec4 diffuseColor = vec4(tableBaseColor(point), 1.0);
    // vec4 diffuseColor = vec4(0.3, 0.2, 0.1, 1.0);
    float diffuseTerm = 0.13 * dot(normalize(normal), normalize(lightPosition - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light2Position - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light3Position - point));

    float ambientTerm = 0.2;

    float shadowVal1 = softshadow(point, normalize(lightPosition - point), 0.2, 10.0, 42.0) + 0.1;
    float shadowVal2 = softshadow(point, normalize(light2Position - point), 0.2, 10.0, 24.0) + 0.1;
    float shadowVal3 = softshadow(point, normalize(light3Position - point), 0.2, 10.0, 42.0) + 0.1;

        // float shadowVal = 1.0;    
    float light1Intensity = 0.8 * shadowVal1;
    float light2Intensity = 0.7 * shadowVal2;
    float light3Intensity = 0.5 * shadowVal3;
    
    // float light1Intensity = 0.8;
    // float light2Intensity = 0.7;
    // float light3Intensity = 0.5;

    vec3 baseColor = diffuseColor.rgb + diffuseTerm;
        float ao = fiveTapAO(point, normal, 5.0);
    // basecolor * (light1.color * light1Intensity + light2.color * light2Intensity)
    return vec4(ao * baseColor * (light1Intensity * light1Color + light2Intensity * light2Color + light3Intensity * light3Color), diffuseColor.a);
}

float spoonSceneSDF(vec3 dir, vec3 p, out vec3 nor, out vec4 col) {
  col = vec4(1.0, 0.0, 0.0, 1.0);

  float light2Dist = sdBox(p - vec3(1.0, 0.5, -2.6 + 0.5 * sin(p.x * 2.0)), vec3(2.0, 1.0, 0.01));
  float tableDist = tableSDF(p);
  float light3Dist = sdBox(p - vec3(4.2, 0.5, -3.5), vec3(2.0, 1.0, 3.0));
  float light1Dist = sdBox(p - vec3(3.2, 0.6, 0.2 + 0.1 * sin(p.x)), vec3(2.0, 1.0, 3.0));

  if (light2Dist < tableDist && light2Dist < light3Dist && light2Dist < light1Dist) {
    // nor = getSaucerNormal(p);
    col = vec4(1.0, 1.0, 1.0, 1.0);
    // col = vec4(1.0, 1.0, 0.0, 1.0);
    return light2Dist;
  } else if (tableDist < light3Dist && tableDist < light1Dist){
    nor = getTableNormal(p);
    col = tableMaterial(nor, p, dir);
    // col = vec4(1.0, 0.0, 0.0, 1.0);
    return tableDist;
  } else if (light3Dist < light1Dist) {
    // nor = getCupNormal(p);
    // col = ceramicMaterial(nor, p, dir);
    col = vec4(1.0, 1.0, 1.0, 1.0);
    return light3Dist;
  } else {
    col = vec4(0.9, 0.9, 0.9, 1.0);
    return light1Dist;
  }
}

vec4 getSpoonReflection(vec3 point, vec3 dir, float mint, float maxt) {
  vec4 col = vec4(1.0);
  vec3 nor = vec3(1.0);
  for( float t=mint; t < maxt; ) {
        float h = spoonSceneSDF(dir, point, nor, col);
        if( h<0.2 ) {
            return col;
        }
        t += h;
    }
  return vec4(0.0, 0.0, 0.0, 1.0);

}



vec4 spoonMaterial(vec3 normal, vec3 point, vec3 dir) {

    vec3 lightPosition = vec3(2.0, 7.0, -3.0);
    vec3 light2Position = vec3(-12.0, 10.0, -3.0);
    vec3 light3Position = vec3(0.0, 10.0, 5.0);
    vec3 light1Color = vec3(0.95, 0.9, 1.0);
    vec3 light2Color = vec3(1.0, 0.9, 0.7);
    vec3 light3Color = vec3(1.0, 1.0, 1.0);


    vec3 baseAlbedo = vec3(0.03, 0.06, 0.02);
    vec4 diffuseColor = vec4(baseAlbedo, 1.0);
    float diffuseTerm = 0.13 * dot(normalize(normal), normalize(lightPosition - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light2Position - point));
    diffuseTerm += 0.13 * dot(normalize(normal), normalize(light3Position - point));

    float ambientTerm = 0.2;

    float shadowVal1 = softshadow(point, normalize(lightPosition - point), 0.2, 10.0, 42.0);
    float shadowVal2 = softshadow(point, normalize(light2Position - point), 0.2, 10.0, 24.0);
    float shadowVal3 = softshadow(point, normalize(light3Position - point), 0.2, 10.0, 42.0);

        // float shadowVal = 1.0;    
    float light1Intensity = 0.8 * shadowVal1;
    float light2Intensity = 0.7 * shadowVal2;
    float light3Intensity = 0.5 * shadowVal3;

    vec3 reflectiveDir = reflect(dir, normal);

    float fresnelCoeff = 1.0 - 0.5 * pow(abs(dot(normalize(normal), normalize(dir))), 5.0);

    float reflectiveTerm = 0.1 * pow(abs(dot(normalize(normal), normalize(point - lightPosition))), 20.0);
    reflectiveTerm += 1.0 * pow((abs(dot(normalize(normal), normalize(point - light2Position)))), 1.5);
    reflectiveTerm += 0.5 * pow(abs(dot(normalize(normal), normalize(point - light3Position))), 1.2);

    diffuseColor += 0.7 * pow(reflectiveTerm, 3.0);

    vec4 reflectiveColor = getSpoonReflection(point, reflectiveDir, 0.2, 30.0);
    // vec4 reflectiveColor = vec4(1.0, 1.0, 1.0, 1.0);
    diffuseColor = mix(reflectiveColor, diffuseColor, fresnelCoeff);
    // diffuseColor = reflectiveColor;

    vec3 baseColor = diffuseColor.rgb + diffuseTerm * reflectiveTerm;
    // basecolor * (light1.color * light1Intensity + light2.color * light2Intensity)
        float ao = fiveTapAO(point, normal, 5.0);

    return vec4(ao * baseColor * (light1Intensity * light1Color + light2Intensity * light2Color + light3Intensity * light3Color), diffuseColor.a);
}




float sceneSDF(vec3 dir, vec3 p, out vec3 nor, out vec4 col) {
  col = vec4(1.0, 0.0, 0.0, 1.0);

  float saucerDist = saucerSDF(p);
  float tableDist = tableSDF(p);
  float cupDist = cupSDF(p);
  float spoonDist = spoonSDF(p);

  float sugarCubeDist = sugarCubesSDF(p);
  // float lightDist = sdBox(p - vec3(0.0, 2.0, 1.0), vec3(3.0, 1.0, 2.0));
  // spoonDist = lightDist;


  // nor = getSphereNormal(p, 2.0);
  // col = ceramicMaterial(nor, p, dir);
  // return sphereSDF(p, 2.0);
  if (saucerDist < tableDist && saucerDist < cupDist && saucerDist < sugarCubeDist && saucerDist < spoonDist) {
    nor = getSaucerNormal(p);
    col = ceramicMaterial(nor, p, dir);
    return saucerDist;
  } else if (tableDist < cupDist && tableDist < sugarCubeDist && tableDist < spoonDist){
    nor = getTableNormal(p);
    col = tableMaterial(nor, p, dir);
    return tableDist;
  } else if (cupDist < sugarCubeDist && cupDist < spoonDist) {
    nor = getCupNormal(p);
    col = ceramicMaterial(nor, p, dir);
    return cupDist;
  } else if (sugarCubeDist < spoonDist) {
    nor = getSugarCubeNormal(p);
    col = sugarMaterial(nor, p, dir);
    return sugarCubeDist;
  } else {
    nor = getSpoonNormal(p);
    col = spoonMaterial(nor, p, dir);
    return spoonDist;
  }
}



bool rayMarch(vec3 dir, out vec3 nor, out vec4 col) {

  float depth = 0.0;
  float dist = 0.0;
  float counter = 0.0;
  float radius = 2.0;
  // if (!sceneBoundingSphere(dir, u_Eye, dist)) {
  //   return false;
  // }
  // float shadowValue = 0.0;
  for (int i = 0; i < 100; i++) {
    vec3 currPoint = u_Eye + depth * dir;
    vec3 normal;
    dist = sceneSDF(dir, currPoint, normal, col);
    if (abs(dist) < epsilon) {
        nor = normal;
        return true;
    }
    depth += dist;
    if (depth > 30.0) {
      nor = vec3(0.0, 0.0, 0.0);
      return false;
    }
  }
  nor = vec3(0.0, 0.0, 0.0);
  return false;

}

void main() {
  vec3 normal = vec3(1.0, 1.0, 1.0);
  vec4 color = vec4(1.0, 1.0, 1.0, 1.0);
  vec3 dir = normalize(castRay(u_Eye));
  float shadowValue;
  if (rayMarch(dir, normal, color)) {
    vec4 diffuseColor = color;
    float diffuseTerm = dot(normalize(normal), normalize(vec3(1.0, 0.5, -1.0)));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
    
    out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
  } else {
    // out_Col = vec4(0.5 * (castRay(u_Eye) + vec3(1.0, 1.0, 1.0)), 1.0);
    out_Col = 0.3 * vec4(0.9 * sin(100.0 * fs_Pos.x), 0.7, 0.8, 1.0);
  }
}