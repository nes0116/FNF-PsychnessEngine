package shaders;

import flixel.system.FlxAssets.FlxShader;

class CircleEffect extends FlxShader
{
	@:glFragmentSource('
		#pragma header

        uniform float radius;

        void main()
        {
            vec2 uv = openfl_TextureCoordv;

            vec2 p = abs(uv - 0.5) - (vec2(0.5) - radius);

            float dist = length(max(p, 0.0)) - radius;

            vec4 c = flixel_texture2D(bitmap, uv);
            vec4 color = mix(vec4(0.0, 0.0, 0.0, 0.5), c, c.a);

            float alpha = 1.0 - smoothstep(
                -1.0 / openfl_TextureSize.x,
                1.0 / openfl_TextureSize.x,
                dist
            );

            gl_FragColor = color * alpha;
        }
	')
	public function new()
	{
		super();
	}
}
