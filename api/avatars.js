// Deploy as a Vercel Function. Set CLOUDINARY_API_KEY and
// CLOUDINARY_API_SECRET in the Vercel project's environment.
export async function GET() {
  const cloud = 'dkk7zqgnz';
  const key = process.env.CLOUDINARY_API_KEY;
  const secret = process.env.CLOUDINARY_API_SECRET;
  if (!key || !secret) {
    return Response.json({ error: 'Avatar catalog unavailable' }, { status: 503 });
  }

  try {
    const url = new URL(`https://api.cloudinary.com/v1_1/${cloud}/resources/by_asset_folder`);
    url.searchParams.set('asset_folder', 'LiveGoal Avatar');
    url.searchParams.set('max_results', '100');
    const response = await fetch(url, {
      headers: { Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}` },
    });
    if (!response.ok) throw new Error('Cloudinary request failed');
    const data = await response.json();
    console.info('Avatar source summary', {
      keyLast4: key.trim().slice(-4),
      responseFields: Object.keys(data),
      resourcesIsArray: Array.isArray(data.resources),
      resourceCount: data.resources?.length ?? null,
      responseError: data.error?.message ?? null,
    });
    const avatars = (data.resources ?? [])
      .filter(asset => asset.resource_type === 'image' && asset.type === 'upload' &&
        typeof asset.secure_url === 'string' && asset.secure_url.startsWith(`https://res.cloudinary.com/${cloud}/image/upload/`))
      .map(asset => ({ id: asset.asset_id, url: asset.secure_url }))
      .filter(asset => typeof asset.id === 'string' && asset.id.length > 0);
    if (avatars.length === 0) {
      return Response.json(
        { error: 'No public images found in the configured Cloudinary product environment and avatar folder.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      );
    }
    return Response.json({ avatars }, {
      headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400' },
    });
  } catch (_) {
    return Response.json({ error: 'Avatar catalog unavailable' }, { status: 502 });
  }
}
