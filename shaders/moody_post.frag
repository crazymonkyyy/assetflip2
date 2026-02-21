#version 330

// Post-processing shader for dark moody atmosphere
// Applied to the final screen render

// Input fragment attributes
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec2 screenSize;
uniform float time;

// Vignette effect
float vignette(vec2 uv, float intensity) {
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);
    return 1.0 - smoothstep(0.4, 1.0, dist * intensity);
}

// Scanline effect
float scanlines(vec2 uv, float intensity) {
    float scanline = sin(uv.y * screenSize.y * 0.5) * 0.5 + 0.5;
    return 1.0 - scanline * intensity;
}

// Subtle chromatic aberration
vec3 chromaticAberration(vec2 uv, float amount) {
    vec2 center = vec2(0.5) - uv;
    float dist = length(center);
    
    float r = texture(texture0, uv + center * dist * amount * 0.002).r;
    float g = texture(texture0, uv).g;
    float b = texture(texture0, uv - center * dist * amount * 0.002).b;
    
    return vec3(r, g, b);
}

// Color grading for dark moody look
vec3 colorGrade(vec3 color) {
    // Desaturate
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, 0.6);
    
    // Color tint - dark purple/blue
    color.r *= 0.85;
    color.g *= 0.8;
    color.b *= 1.0;
    
    // Contrast
    color = (color - 0.5) * 1.4 + 0.5;
    
    // Shadows darker
    color *= 0.8;
    
    // Slight teal in shadows
    if (luminance < 0.3) {
        color.g *= 1.1;
        color.b *= 1.15;
    }
    
    return color;
}

// Film grain
float grain(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    vec2 uv = fragTexCoord;
    
    // Chromatic aberration on edges
    vec3 color = chromaticAberration(uv, 1.0);
    
    // Apply color grading
    color = colorGrade(color);
    
    // Vignette
    float vig = vignette(uv, 1.3);
    color *= vig;
    
    // Subtle scanlines
    float scans = scanlines(uv, 0.03);
    color *= scans;
    
    // Film grain
    float filmGrain = grain(uv * time + uv * 100.0) * 0.04;
    color += filmGrain;
    
    // Slight flicker
    float flicker = sin(time * 2.0) * 0.02 + 0.98;
    color *= flicker;
    
    finalColor = vec4(color, 1.0);
}
