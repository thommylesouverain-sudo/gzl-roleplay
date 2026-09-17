texture gTexture;

technique TextureReplace
{
    pass P0
    {
        Texture[0] = gTexture;
        AlphaBlendEnable = TRUE;
        AlphaTestEnable = TRUE;
        AlphaRef = 1;
        AlphaFunc = GreaterEqual;
    }
}

technique Fallback
{
    pass P0
    {
        Texture[0] = gTexture;
    }
}
