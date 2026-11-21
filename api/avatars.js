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
    console.info('Avatar catalog source', {
      resourceCount: Array.isArray(data.resources) ? data.resources.length : null,
      firstResourceFields: Object.keys(data.resources?.[0] ?? {}),
      firstResourceType: data.resources?.[0]?.resource_type ?? null,
      firstDeliveryType: data.resources?.[0]?.type ?? null,
      firstAssetFolder: data.resources?.[0]?.asset_folder ?? null,
    });
    if ((data.resources ?? []).length === 0) {
      const headers = { Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}` };
      const [foldersResponse, imagesResponse] = await Promise.all([
        fetch(`https://api.cloudinary.com/v1_1/${cloud}/folders`, { headers }),
        fetch(`https://api.cloudinary.com/v1_1/${cloud}/resources/image/upload?max_results=10`, { headers }),
      ]);
      const folders = foldersResponse.ok ? await foldersResponse.json() : {};
      const images = imagesResponse.ok ? await imagesResponse.json() : {};
      console.info('Avatar catalog diagnosis', {
        foldersStatus: foldersResponse.status,
        rootFolderNames: folders.folders?.map(folder => folder.name) ?? [],
        imagesStatus: imagesResponse.status,
        sampleImageFolders: images.resources?.map(asset => asset.asset_folder) ?? [],
      });
    }
    const avatars = (data.resources ?? [])
      .filter(asset => asset.resource_type === 'image' && asset.type === 'upload' &&
        typeof asset.secure_url === 'string' && asset.secure_url.startsWith(`https://res.cloudinary.com/${cloud}/image/upload/`))
      .map(asset => ({ id: asset.asset_id, url: asset.secure_url }))
      .filter(asset => typeof asset.id === 'string' && asset.id.length > 0);
    console.info('Avatar catalog filtered', { count: avatars.length });
    return Response.json({ avatars }, {
      headers: { 'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400' },
    });
  } catch (_) {
    return Response.json({ error: 'Avatar catalog unavailable' }, { status: 502 });
  }
}
