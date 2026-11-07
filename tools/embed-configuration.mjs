import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'build/generated/USConfigurationData.swift');
const modern=fs.readFileSync(path.join(root,'Resources/Configuration/resolveconfiguration_9_1_76.bnk')).toString('base64');
const legacy=fs.readFileSync(path.join(root,'Resources/Configuration/resolveconfiguration.bnk')).toString('base64');
fs.mkdirSync(path.dirname(out),{recursive:true});
fs.writeFileSync(out,`import Foundation\n// Exact supplied configuration snapshots embedded for IPA injection.\nenum USConfigurationData {\n static let modern = Data(base64Encoded: "${modern}")!\n static let legacy = Data(base64Encoded: "${legacy}")!\n}\n`);
