function [tomatoData, metadata] = buildTomatoDataset(cfg)
%BUILDTOMATODATASET Excel + visco + yield を id ごとに統合

excelFile = cfg.raw.excelFile;
viscoDir = cfg.raw.viscoDir;
yieldDir = cfg.raw.yieldDir;

if ~isfile(excelFile)
    error("Excelファイルが見つかりません: %s", excelFile);
end
if ~isfolder(viscoDir)
    error("viscoフォルダが見つかりません: %s", viscoDir);
end
if ~isfolder(yieldDir)
    error("yieldフォルダが見つかりません: %s", yieldDir);
end

excelData = readSizeWeightWideFormat(excelFile);
if isempty(excelData.id)
    error("Excelファイルから有効なトマト番号を取得できませんでした。");
end

viscoMap = buildFileMap(viscoDir, "v");
yieldMap = buildFileMap(yieldDir, "y");

viscoIds = sort(cell2mat(keys(viscoMap)));
yieldIds = sort(cell2mat(keys(yieldMap)));
excelIds = sort(unique(excelData.id));

commonIds = intersect(excelIds, intersect(viscoIds, yieldIds));
fprintf("統合対象トマト数: %d\n", numel(commonIds));

tomatoData = struct( ...
    "id", {}, "weight", {}, "size", {}, "sourceColumn", {}, "visco", {}, "yield", {});

for i = 1:numel(commonIds)
    id = commonIds(i);
    idx = find(excelData.id == id, 1, "first");
    tomatoData(i).id = id;
    tomatoData(i).weight = excelData.weight(idx);
    tomatoData(i).size = struct( ...
        "x", excelData.sizeX(idx), "y", excelData.sizeY(idx), ...
        "z", excelData.sizeZ(idx), "mean", excelData.sizeMean(idx));
    tomatoData(i).sourceColumn = excelData.sourceColumn(idx);
    tomatoData(i).visco = readViscoCsv(viscoMap(id));
    tomatoData(i).yield = readYieldCsv(yieldMap(id));
end

metadata = struct();
metadata.createdAt = datetime("now");
metadata.excelFile = excelFile;
metadata.viscoDir = viscoDir;
metadata.yieldDir = yieldDir;
metadata.commonIds = commonIds;
metadata.missingInVisco = setdiff(excelIds, viscoIds);
metadata.missingInYield = setdiff(excelIds, yieldIds);
end

function out = readSizeWeightWideFormat(excelFile)
raw = readcell(excelFile);
idRow = detectIdRow(raw);
weightRow = detectLabelRow(raw, "weight");
xRow = detectLabelRow(raw, "x");
yRow = detectLabelRow(raw, "y");
zRow = detectLabelRow(raw, "z");
if isnan(idRow) || isnan(weightRow)
    error("Excelのレイアウトを自動判定できませんでした。");
end
nCol = size(raw, 2);
ids = []; weights = []; sx = []; sy = []; sz = []; srcCol = [];
for c = 2:nCol
    id = toNumeric(raw{idRow, c});
    if isnan(id), continue; end
    ids(end + 1, 1) = round(id); %#ok<AGROW>
    weights(end + 1, 1) = toNumeric(raw{weightRow, c}); %#ok<AGROW>
    sx(end + 1, 1) = toNumeric(raw{xRow, c}); %#ok<AGROW>
    sy(end + 1, 1) = toNumeric(raw{yRow, c}); %#ok<AGROW>
    sz(end + 1, 1) = toNumeric(raw{zRow, c}); %#ok<AGROW>
    srcCol(end + 1, 1) = c; %#ok<AGROW>
end
out = struct("id", ids, "weight", weights, "sizeX", sx, "sizeY", sy, ...
    "sizeZ", sz, "sizeMean", mean([sx, sy, sz], 2, "omitnan"), "sourceColumn", srcCol);
end

function rowIdx = detectIdRow(raw)
rowIdx = nan;
for r = 1:size(raw, 1)
    numericCount = 0;
    for c = 2:size(raw, 2)
        if ~isnan(toNumeric(raw{r, c})), numericCount = numericCount + 1; end
    end
    if numericCount >= 5, rowIdx = r; return; end
end
end

function rowIdx = detectLabelRow(raw, label)
rowIdx = nan;
for r = 1:size(raw, 1)
    if strcmpi(strtrim(string(raw{r, 1})), label), rowIdx = r; return; end
end
end

function m = buildFileMap(targetDir, prefix)
files = dir(fullfile(char(targetDir), sprintf("%s*.*", char(prefix))));
m = containers.Map("KeyType", "double", "ValueType", "char");
for i = 1:numel(files)
    if files(i).isdir, continue; end
    [~, name, ext] = fileparts(files(i).name);
    if ~strcmpi(ext, ".csv"), continue; end
    tok = regexp(name, sprintf("^%s(\\d+)$", char(prefix)), "tokens", "once", "ignorecase");
    if isempty(tok), continue; end
    id = str2double(tok{1});
    if isfinite(id), m(id) = fullfile(files(i).folder, files(i).name); end
end
end

function out = readViscoCsv(filePath)
tbl = readtable(filePath, "Delimiter", ",", "NumHeaderLines", 102, ...
    "ReadVariableNames", false, "FileEncoding", "Shift_JIS");
microSecRaw = toDoubleVector(tbl{:, 2});
microSec = unwrapMicroseconds(microSecRaw);
signal = toDoubleVector(tbl{:, 3});
deformation = (signal - 4) .* (70 / 16) - 35;
[microSec, signal, deformation] = trimTail(microSec, signal, deformation, 6);
out = struct("file", filePath, "microSec", microSec, "signal", signal, "deformation", deformation);
end

function out = readYieldCsv(filePath)
tbl = readtable(filePath, "Delimiter", ",", "FileEncoding", "Shift_JIS", ...
    "VariableNamingRule", "preserve", "ReadVariableNames", true);
out = struct("file", filePath, "sec", toDoubleVector(tbl{:, 2}), ...
    "deformation", toDoubleVector(tbl{:, 3}), "force", toDoubleVector(tbl{:, 4}));
end

function v = toDoubleVector(x)
if isnumeric(x), v = double(x); return; end
if iscell(x)
    v = nan(size(x));
    for i = 1:numel(x), v(i) = toNumeric(x{i}); end
    return;
end
v = str2double(string(x));
end

function n = toNumeric(v)
if isempty(v), n = nan; return; end
if isnumeric(v)
    n = double(v(1)); return;
end
if isstring(v) || ischar(v)
    s = strtrim(string(v));
    if strlength(s) == 0, n = nan; return; end
    n = str2double(s);
    if isnan(n)
        tok = regexp(char(s), "\d+(\.\d+)?", "match", "once");
        n = ifelse(isempty(tok), nan, str2double(tok));
    end
    return;
end
n = str2double(string(v));
end

function v = ifelse(cond, a, b)
if cond, v = a; else, v = b; end
end

function unwrapped = unwrapMicroseconds(us)
unwrapped = us;
if isempty(us), return; end
offset = 0;
for i = 2:numel(us)
    if isnan(us(i)) || isnan(us(i - 1))
        unwrapped(i) = us(i) + offset; continue;
    end
    if us(i) < us(i - 1), offset = offset + 1e6; end
    unwrapped(i) = us(i) + offset;
end
end

function varargout = trimTail(varargin)
nTrim = varargin{end};
arrs = varargin(1:end-1);
n = numel(arrs{1});
trimN = min(nTrim, n);
keepIdx = 1:(n - trimN);
varargout = cell(size(arrs));
for i = 1:numel(arrs), varargout{i} = arrs{i}(keepIdx); end
end
