#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const float epsilon = 0.001;
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

float fbm(float x, float y, float height, float xScale, float yScale) {
  float total = 0.f;
  float persistence = 0.5f;
  int octaves = 2;
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
  int octaves = 2;
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

float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 d = abs(p) - b;
  return length(max(d,0.0)) - r
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
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
  // return 10000.0;
  vec3 tableTranslate = vec3(0.0, 1.2, 0.0);;
  return sdBox(p + tableTranslate, vec3(20.0, 0.1, 10.0));
  // return sdPlane(p, normalize(vec4(0.0, 1.0, 0.0, 1.0)));
  // vec3 pScale = vec3(0.5, 4.0, 0.5);
  // vec3 pTranslate = vec3(0.0, 0.0, 0.0);
  // return sdRoundedCylinder(p * pScale + pTranslate, 1.0, 1.0, 1.0);
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
  float baseConeDist = sdCappedCone(p + baseConeTransform, 0.3, 1.2, 0.7);

  vec3 sphereScale = vec3(0.73, 1.05, 0.73);
  vec3 sphereTranslate = vec3(0.0, -0.8, 0.0); 
  float baseSphereDist = sphereSDF(p * sphereScale + sphereTranslate, 1.1);

  vec3 subtractBoxScale = vec3(0.55, 0.35, 0.55);
  vec3 subtractBoxTranslate = vec3(0.0, -1.38, 0.0); 
  float subtractBoxDist = sdBox(p * subtractBoxScale + subtractBoxTranslate, vec3(1.0, 1.0, 1.0));
  baseSphereDist = opSubtraction(subtractBoxDist, baseSphereDist);

  vec3 cupCylScale = vec3(0.4, 0.8, 0.4);
  vec3 cupCylTranslate = vec3(0.0, -1.4, 0.0);
  float cupCylDist = sdCappedCylinder(p * cupCylScale + cupCylTranslate, vec2(1.0, 1.0));

  vec3 torusTranslate = vec3(0.0, -1.0, 0.0);
  vec3 torusScale = vec3(1.0, 0.74, 1.0);
  float cutoutTorus = sdTorus(p * torusScale + torusTranslate, vec2(5.25, 3.5));
  cupCylDist = opSmoothSubtraction(cutoutTorus, cupCylDist, 0.1);

  vec3 cupCylSubtractScale = vec3(0.5, 0.89, 0.5);
  vec3 cupCylSubtractTranslate = vec3(0.0, -1.7, 0.0);
  float cupCylSubtractDist = sdCappedCylinder(p * cupCylSubtractScale + cupCylSubtractTranslate, vec2(1.0, 1.0));
  
  vec3 torus2Translate = vec3(0.0, -1.0, 0.0);
  vec3 torus2Scale = vec3(1.0, 0.77, 1.0);
  float cutout2Torus = sdTorus(p * torusScale + torusTranslate, vec2(5.2, 3.5));
  cupCylSubtractDist = opSubtraction(cutout2Torus, cupCylSubtractDist);

  cupCylDist = opSubtraction(cupCylSubtractDist, cupCylDist);
  return opSmoothUnion(opSmoothUnion(baseConeDist, baseSphereDist, 0.2), cupCylDist, 0.3);
}

float sugarCubesSDF(vec3 p) {
  vec3 cube1Translate = vec3(-2.0, 0.0, 4.0);
  vec3 cube1Scale = vec3(1.0, 2.0, 2.0);
  float cube1Dist = sdRoundBox(p * cube1Scale + cube1Translate, vec3(1.0, 1.0, 1.0), 2.0);
  // return cube1Dist;
  return 10.0;

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
float sceneSDFnoMat(vec3 p) {

  // return sphereSDF(p, 2.0);

  float saucerDist = saucerSDF(p);
  float tableDist = tableSDF(p);
  float cupDist = cupSDF(p);

  if (saucerDist < tableDist && saucerDist < cupDist) {

    return saucerDist;
  } else if (tableDist < cupDist){

    return tableDist;
  } else {

    return cupDist;
  }
}

// float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k)
// {
//     float res = 1.0;
//     for( float t=mint; t < maxt; )
//     {
//         float h = sceneSDFnoMat(ro + rd*t);
//         if( h<.01 * epsilon )
//             return 0.0;
//         res = min( res, k*h/t );
//         t += h;
//     }
//     return res;
// }

float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    float ph = 1e20;
    float counter = 0.0;
    for( float t=mint; t < maxt; )
    {
        float h = sceneSDFnoMat(ro + rd*t);
        if( abs(h)< 0.1 * epsilon ) {
            return 0.0;
        }
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min(res, k*d/max(0.0,t-y));
        ph = h;
        t += h;
        counter ++;
        if (counter > 50.0) {
          return res;
        }
    }
    return res;
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
    // float shadowVal = softshadow(point, normalize(lightPosition - point), 0.07, 3.0, 32.0);
    float shadowVal = 1.0;
    vec3 shadowColor = vec3(0.07, 0.1, 0.15);
    return vec4(shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm * reflectiveTerm * vec3(0.8, 0.6, 1.0)), diffuseColor.a);
        // return vec4((1.0 - shadowVal) * shadowColor + shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm * reflectiveTerm * vec3(0.8, 0.6, 1.0)), diffuseColor.a);

}

vec4 tableMaterial(vec3 normal, vec3 point, vec3 dir) {
  // normal.y += 0.8 * fbm3D(point.x, point.y, point.z, 3.0, 2.5, 2.5, 2.5);
  //   normal.x += 0.7* fbm3D(point.x + 2.0, point.y, point.z, 1.0, 3.0, 3.0, 3.0);
    vec3 lightPosition = vec3(3.0, 7.0, -3.0);
    vec4 diffuseColor = vec4(0.95, 0.95, 0.9, 1.0);
    float diffuseTerm = dot(normalize(normal), normalize(lightPosition - point));
    float ambientTerm = 0.2;
    float lightIntensity = diffuseTerm + ambientTerm;
    vec3 shadowPoint = point + epsilon * normalize((lightPosition - point));
    // float shadowVal = softshadow(point, normalize(lightPosition - point), 0.1, 10.0, 32.0);
        float shadowVal = 1.0;

    vec3 shadowColor = vec3(0.07, 0.1, 0.15);
    return vec4(shadowColor + shadowVal * (diffuseColor.rgb * lightIntensity + diffuseTerm), diffuseColor.a);
}




float sceneSDF(vec3 dir, vec3 p, out vec3 nor, out vec4 col) {
  col = vec4(1.0, 0.0, 0.0, 1.0);

  float saucerDist = saucerSDF(p);
  float tableDist = tableSDF(p);
  float cupDist = cupSDF(p);
  float sugarCubeDist = sugarCubesSDF(p);

  // nor = getSphereNormal(p, 2.0);
  // col = ceramicMaterial(nor, p, dir);
  // return sphereSDF(p, 2.0);

  if (saucerDist < tableDist && saucerDist < cupDist && saucerDist < sugarCubeDist) {
    nor = getSaucerNormal(p);
    col = ceramicMaterial(nor, p, dir);
    return saucerDist;
  } else if (tableDist < cupDist && tableDist < sugarCubeDist){
    nor = getTableNormal(p);
    col = tableMaterial(nor, p, dir);
    return tableDist;
  } else if (cupDist < sugarCubeDist) {
    nor = getCupNormal(p);
    col = ceramicMaterial(nor, p, dir);
    return cupDist;
  } else {
    nor = getSugarCubeNormal(p);
    col = tableMaterial(nor, p, dir);
    return sugarCubeDist;
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
  for (int i = 0; i < 256; i++) {
    vec3 currPoint = u_Eye + depth * dir;
    vec3 normal;
    dist = sceneSDF(dir, currPoint, normal, col);
    if (abs(dist) < epsilon) {
        nor = normal;
        return true;
    }
    depth += dist;
    if (depth > 50.0) {
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
    out_Col = vec4(0.5 * (castRay(u_Eye) + vec3(1.0, 1.0, 1.0)), 1.0);
  }
}