#version 330

// Fragment shader for dark moody atmosphere
// Features: Dark ambient, fog, vignette, desaturation

// Input fragment attributes (from vertex shader)
in vec3 fragPosition;
in vec3 fragNormal;
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Input uniform values
uniform vec3 viewPos;
uniform vec4 colDiffuse;
uniform vec2 screenSize;
uniform float time;

// Dark color palette
const vec3 FOG_COLOR = vec3(0.02, 0.02, 0.05);
const vec3 AMBIENT_COLOR = vec3(0.08, 0.08, 0.12);
const vec3 DARK_PURPLE = vec3(0.15, 0.1, 0.2);
const vec3 DARK_GREEN = vec3(0.05, 0.1, 0.08);

// Noise function for atmosphere
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Vignette effect
float vignette(vec2 uv, float intensity) {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    return 1.0 - smoothstep(0.3, 0.9, dist * intensity);
}

// Color grading - dark moody look
vec3 colorGrade(vec3 color) {
    // Desaturate slightly
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, 0.7);
    
    // Push towards dark purple/green
    color.r *= 0.9;
    color.g *= 0.85;
    color.b *= 1.1;
    
    // Increase contrast
    color = (color - 0.5) * 1.3 + 0.5;
    
    // Darken shadows
    color *= 0.85;
    
    return color;
}

void main()
{
    // Base texture color
    vec4 texColor = texture(diffuse0, fragTexCoord);
    vec3 color = texColor.rgb * fragColor.rgb;
    
    // Calculate distance from view for fog
    float dist = length(fragPosition - viewPos);
    float fogDensity = 0.03;
    float fogFactor = 1.0 - exp(-dist * fogDensity);
    fogFactor = clamp(fogFactor, 0.0, 1.0);
    
    // Apply fog
    color = mix(color, FOG_COLOR, fogFactor);
    
    // Add subtle rim lighting
    vec3 viewDir = normalize(viewPos - fragPosition);
    float rim = 1.0 - max(0.0, dot(fragNormal, viewDir));
    rim = pow(rim, 3.0) * 0.3;
    color += vec3(0.1, 0.15, 0.2) * rim;
    
    // Add subtle atmospheric noise
    float atmosNoise = noise(fragTexCoord * 10.0 + time * 0.1) * 0.03;
    color += atmosNoise;
    
    // Apply color grading
    color = colorGrade(color);
    
    // Apply vignette
    float vig = vignette(fragTexCoord, 1.5);
    color *= vig;
    
    // Final darkening
    color *= 0.7;
    
    finalColor = vec4(color, texColor.a * fragColor.a);
}
