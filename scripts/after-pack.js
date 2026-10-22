const AUTHOR = 'lionrealone';
const path = require('path');
const fs = require('fs');
const { flipFuses, FuseVersion, FuseV1Options } = require('@electron/fuses');
const rcedit = require('rcedit');

async function applyIcon(exe, icon) {
  if (!fs.existsSync(exe) || !fs.existsSync(icon)) return;
  await rcedit(exe, {
    icon,
    'version-string': {
      CompanyName: AUTHOR,
      FileDescription: 'Find The Needle',
      ProductName: 'Find The Needle',
      LegalCopyright: AUTHOR,
    },
    'product-version': '1.0.1',
    'file-version': '1.0.1',
  });
}

exports.default = async function afterPack(context) {
  if (context.electronPlatformName !== 'win32') return;

  const exeName = `${context.packager.appInfo.productFilename}.exe`;
  const exe = path.join(context.appOutDir, exeName);
  const buildDir = path.join(context.packager.projectDir, 'build');
  const steamIcon = path.join(buildDir, 'steam-original.ico');
  const icon = fs.existsSync(steamIcon)
    ? steamIcon
    : path.join(buildDir, 'icon.ico');

  await applyIcon(exe, icon);

  await flipFuses(exe, {
    version: FuseVersion.V1,
    [FuseV1Options.RunAsNode]: false,
    [FuseV1Options.EnableCookieEncryption]: true,
    [FuseV1Options.EnableNodeOptionsEnvironmentVariable]: false,
    [FuseV1Options.EnableNodeCliInspectArguments]: false,
    [FuseV1Options.EnableEmbeddedAsarIntegrityValidation]: false,
    [FuseV1Options.OnlyLoadAppFromAsar]: false,
  });
};
