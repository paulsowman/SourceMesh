function varargout = atemplate(varargin)
% Add networks and overlays to a smoothed brain mesh or gifti object.
%
% NOTE: Unknown BUG when using with Matlab 2015a on Linux.
% Working with Matlab 2014a & 2017a on Mac & Matlab 2012a on Linux.
%
% IF you get error using the mex files, delete them. 
% 
%
%  MESHES:
%--------------------------------------------------------------------------
%
%  atemplate()               plot a template mesh
%  atemplate('gifti',mesh)   plot a supplied (gifti) mesh
%  atemplate('gifti',mesh, 'write',name);  plot mesh & write out gifti
%  
%
%  OVERLAYS:
%--------------------------------------------------------------------------
%
%  atemplate('overlay',L);   plot template mesh with overlay from AAL90. L is [90x1]
%
%  atemplate('sourcemodel',sormod,'overlay',L)  plot template with overlay
%  values L at sourcemodel values sormod, interpolated on surface.
%
%  atemplate('gifti',mesh,'sourcemodel',sormod,'overlay',L)  plot the supplied 
%  gifti mesh with overlay values L at sourcemodel locations sormod interpolated 
%  on surface. Sormod is n-by-3, L is n-by-1.
%
%  atemplate('gifti',mesh,'sourcemodel',sormod,'overlay',L,'write','MYGifti')  
%  - This does the plot as above but writes out TWO gifti files:
%    1. MYGifti.gii is the gifti mesh 
%    2. MYGiftiOverlay.gii is the corresponding overlay data
%
%
%  **Note on sourcemodel option: If sourcemodel from Fieldtrip, swap x & y
%  by doing sm = [sourcemod(:,2),sourcemod(:,1),sourcemod(:,3)];
%
%
%  VIDEO OVERLAY:
%--------------------------------------------------------------------------
%
%  atemplate('gifti',g,'sourcemodel',sormod,'video',m,'name',times); where
%  - g      = the gifti surface to plot
%  - sormod = sourcemodel vertices
%  - m      = overlay values [vertices * ntimes] 
%  - name   = video savename
%  - times  = vector of titles (time values?)
%
%
%  NETWORKS:
%--------------------------------------------------------------------------
%
%  atemplate('network',A);    plot template mesh with 90x90 AAL network, A.
%
%  atemplate('sourcemodel',sormod,'network',A);  plot network A  at
%  sourcemodel locations in sormod. sormod is n-by-3, netowrk is n-by-n.
%
%  atemplate('sourcemodel',sormod,'network',A,'write','savename'); 
%   - as above but writes out .node and .edge files for the network, and
%   the gifti mesh file.
%
%
%  OTHER
%--------------------------------------------------------------------------
%
%  atemplate('labels');         plot node labels (AAL90) 
%
%  atemplate('labels', all_roi_tissueindex, labels); where all_roi_tissue 
%  is a 1-by-num-vertices vector containing indices of the roi this vertex
%  belongs to, and 'labels' contains the labels for each roi. The text
%  labels are added at the centre of the ROI.
%  
%  Labels notes:
%     - If plotting a network, only edge-connected nodes are labelled.
%     - If plotting a set of nodes (below), only those are labelled.
%     - Otherwise, all ROIs/node labels are added!
%
%  atemplate('nodes', N);             Plot dots at node==1, i.e. N=[90,1]
%  atemplate('tracks',tracks,header); plot tracks loaded with trk_read
%
%  Note: any combination of the inputs should be possible.
%
%
%
%
%  AN EXAMPLE NETWORK: from 5061 vertex sourcemodel with AAL90 labels
%--------------------------------------------------------------------------
%
% load New_AALROI_6mm.mat       % load ft source model, labels and roi_inds
%
% net  = randi([0 1],5061,5061);   % generate a network for this sourmod
% pos  = template_sourcemodel.pos; % get sourcemodel vertices
% labs = AAL_Labels;               % roi labels
% rois = all_roi_tissueindex;      % roi vertex indices
%
% atemplate('sourcemodel',pos,'network',net,'labels',rois,labs);
%
%
%
%
%
%  Cortical mesh from mri
%  ---------------------------
%  If the gifti option is included, input (g) may be the filename of a 
%  coregistered ctf .mri file. This will call Vol2SurfAS which uses 
%  fieldtrip & isosurface to normalise, align, segment and extract a
%  cortical surface. This is then centred, smoothed and converted to a
%  gifti object.
%
%  See also: slice3() slice2()
%
% ^trk_read requires along-tract-stats toolbox
%
% AS17


% Parse inputs
%--------------------------------------------------------------------------
pmesh  = 1;
labels = 0;
write  = 0;
fname  = [];
fighnd = [];
colbar = 1;
template  = 0;
thelabels = [];
all_roi_tissueindex = [];

for i  = 1:length(varargin)
    if strcmp(varargin{i},'overlay');     L   = varargin{i+1}; end
    if strcmp(varargin{i},'sourcemodel'); pos = varargin{i+1}; end
    if strcmp(varargin{i},'network');     A   = varargin{i+1}; end
    if strcmp(varargin{i},'tracks');      T   = varargin{i+1}; H = varargin{i+2}; end
    if strcmp(varargin{i},'nosurf');      pmesh  = 0;            end
    if strcmp(varargin{i},'nodes');       N = varargin{i+1};     end
    if strcmp(varargin{i},'gifti');       g = varargin{i+1};     end
    if strcmp(varargin{i},'write');       write  = 1; fname = varargin{i+1}; end
    if strcmp(varargin{i},'fighnd');      fighnd = varargin{i+1}; end
    if strcmp(varargin{i},'nocolbar');    colbar = 0;             end
    if strcmp(varargin{i},'video');       V     = varargin{i+1}; fpath = varargin{i+2}; times = varargin{i+3}; end
    if strcmp(varargin{i},'othermesh');   M = varargin{i+1}; O = varargin{i+2};   end  
    if strcmp(varargin{i},'labels');      labels = 1;
        try all_roi_tissueindex = varargin{i+1};
            thelabels = varargin{i+2};
        end
    end
    if strcmp(varargin{i},'template'); template = 1;
        model = varargin{i+1};
    end    
end






% template space
%--------------------------------------------------------------------------
if template
    atlas = dotemplate(model,pos);
    pos   = atlas.pos;
    try L;
        S  = [min(L(:)) max(L(:))];
        NM = atlas.M/sum(atlas.M(:));
        NL = L(:)'*NM';
        L  = S(1) + ((S(2)-S(1))).*(NL - min(NL))./(max(NL) - min(NL));
    end
end


% Sourcemodel vertices
%--------------------------------------------------------------------------
try   pos;
      fprintf('Using supplied sourcemodel vertices\n');
catch fprintf('Using AAL90 source vertices by default\n');
      load('AAL_SOURCEMOD');
      pos  = template_sourcemodel.pos;
end

% Centre sourcemodel
pos = pos - repmat(spherefit(pos),[size(pos,1),1]);






% Plot Surface
%--------------------------------------------------------------------------
try   mesh = g;
      fprintf('Using user provided mesh\n');
      if ischar(mesh);
          % generate a cortical mesh from the mri (Vol2SurfAS)
          fprintf('MRI (%s) is character (a filename?): attempting to load, segment & mesh\n',mesh);
          mesh = Vol2SurfAS(mesh,'ctf','smooth',0.15);
          fprintf('\n\nSuccessfully generated subject mesh from .mri!\n');
      end
catch mesh = read_nv();
      fprintf('(Using template brain mesh)\n');
end


% plot the glass brain
%--------------------------------------------------------------------------
if     pmesh && ~exist('T','var');
       mesh = meshmesh(mesh,write,fname,fighnd,.3,pos);
elseif pmesh
       mesh = meshmesh(mesh,write,fname,fighnd,.3,pos);
end





% find closest vertices and overlay
%--------------------------------------------------------------------------
try L; overlay(mesh,double(L),write,fname,colbar,pos);end 

isover = exist('L','var') || exist('V','var');
if  isover && exist('A','var') 
    colbar = 0;
    alpha(.2);
end



% draw edges and edge-connected nodes
%--------------------------------------------------------------------------
try A; connections(A,colbar,pos,write,fname); end 


% draw dti tracks loaded with trk_read
%--------------------------------------------------------------------------
try T; drawtracks(T,H,mesh);                  end 


% draw N(i) = 1 nodes
%--------------------------------------------------------------------------
try N; drawnodes(N,pos);                      end 


% Add labels
%--------------------------------------------------------------------------
if labels; 
    if     exist('A','var'); addlabels(A,pos,all_roi_tissueindex,thelabels);
    elseif exist('N','var'); 
        if sum(ismember(size(N),[1 90])) == 2
            addlabels(diag(N),pos,all_roi_tissueindex,thelabels);
        elseif sum(ismember(size(N),[1 90])) == 1
            addlabels(diag(sum(N,2)),pos,all_roi_tissueindex,thelabels);
        end
    else;  n = length(pos);
           addlabels(ones(n,n),pos,all_roi_tissueindex,thelabels);
    end
end

% Make Video
%--------------------------------------------------------------------------
try V; 
    tv = 1:size(V,2);
    try tv = times; end
    video(mesh,V,1,fpath,tv,pos); 
end


end


% FUNCTIONS
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------



function atlas = dotemplate(model,pos)
% Put dense sourcemodel into an atlas space using ICP and linear
% interpolation
%
%
%

switch model
    case lower('aal');   load AAL_SOURCEMOD
    otherwise
        fprintf('Model not found.\n');
        return;
end

atlas.pos = template_sourcemodel.pos;
M         = zeros( length(atlas.pos), length(pos) );
r         = ceil(length(pos)/length(atlas.pos)*1.3);
w         = fliplr(linspace(.1,1,r));         
for i = 1:length(atlas.pos)
    
    % reporting
    if i > 1; fprintf(repmat('\b',[size(str)])); end
    str = sprintf('%d/%d',i,(length(atlas.pos)));
    fprintf(str);
    
    % find closest point[s] in cortical mesh
    dist       = cdist(pos,atlas.pos(i,:));
    [junk,ind] = maxpoints(dist,r,'min');
    M (i,ind)  = w;
end
for i = 1:size(M,1)
    M(i,:) = M(i,:) / sum(M(i,:));
end

atlas.M = M;

end

function connections(A,colbar,pos,write,fname)
% Network (Node & Edges) plotter.
%
%


% Edges
%-------------------------------------------------------------
[node1,node2,strng] = matrix2nodes(A,pos);
RGB = makecolbar(strng);

% LineWidth (scaled) for strength
if any(strng)
    R = [min(strng),max(strng)];
    S = ( strng - R(1) ) + 1e-3;
    
    % If all edges same value, make thicker
    if  max(S(:)) == 1e-3; 
        S = 3*ones(size(S)); 
    end
else
    S = [0 0];
end

% If too few strengths, just use red edges
%-------------------------------------------------------------------
LimC = 1;
if all(all(isnan(RGB)))
    RGB  = repmat([1 0 0],[size(RGB,1) 1]);
    LimC = 0;
end

% Paint edges
%-------------------------------------------------------------------
for i = 1:size(node1,1)
    line([node1(i,1),node2(i,1)],...
        [node1(i,2),node2(i,2)],...
        [node1(i,3),node2(i,3)],...
        'LineWidth',S(i),'Color',[RGB(i,:)]);
end

% Set colorbar only if there are valid edges
%-------------------------------------------------------------------
if any(i) && colbar
    set(gcf,'DefaultAxesColorOrder',RGB)
    if colbar
        colorbar
    end
end
if LimC && colbar
    caxis(R);
end

drawnow;


% Nodes (of edges only)
%-------------------------------------------------------------
hold on;
for i = 1:size(node1,1)
    scatter3(node1(i,1),node1(i,2),node1(i,3),'filled','k');
    scatter3(node2(i,1),node2(i,2),node2(i,3),'filled','k');
end

drawnow;

if write;
   fprintf('Writing network: .edge & .node files\n');
   conmat2nodes(A,fname,'sourcemodel',pos);
end


end

function [node1,node2,strng] = matrix2nodes(A,pos)
% Write node & edge files for the AAL90 atlas
% Also returns node-to-node coordinates for the matrix specified.
%
% Input is the n-by-n connectivity matrix
% Input 2 is the sourcemodel vertices, n-by-3
%
% AS2017



node1 = []; node2 = []; strng = [];
for i = 1:length(A)
    [ix,iy,iv] = find(A(i,:));
    
    if ~isempty(ix)
        conns = max(length(ix),length(iy));
        for nc = 1:conns
            node1 = [node1; pos(i(1),:)];
            node2 = [node2; pos(iy(nc),:)];
            strng = [strng; iv(nc)];
        end
    end
end

end


function drawnodes(N,pos)
% Node plotter. N = (90,1) with 1s for nodes to plot and 0s to ignore.
%
% 

hold on;
v       = pos*0.9;


if size(N,1) > 1 && size(N,2) > 1
    cols = {'r' 'm','y','g','c','b'};
    if size(size(N,2)) == 90
        N = N';
    end
    
    for j = 1:size(N,2)
        ForPlot = v(find(N(:,j)),:) + (1e-2 * (2*j) ) ;
        s       = find(N);
        col     = cols{j};
        for i   = 1:length(ForPlot)
            scatter3(ForPlot(i,1),ForPlot(i,2),ForPlot(i,3),70,col,'filled',...
                'MarkerFaceAlpha',.6,'MarkerEdgeAlpha',.6);        hold on;
        end
    end
    
else
    ForPlot = v(find(N),:);
    s       = find(N);
    for i = 1:length(ForPlot)
    %     if     i < 3; col = 'b';
    %     elseif i > 2 && i < 5; col = 'r';
    %     elseif i > 4 ; col = 'g';
    %     end
        col = 'r';
        scatter3(ForPlot(i,1),ForPlot(i,2),ForPlot(i,3),s(i),'r','filled');
    end
end
set(gcf,'DefaultAxesColorOrder',RGB); jet;
colorbar

end

function RGB = makecolbar(I)
% Register colorbar values to our overlay /  T-vector
%

Colors   = jet;
NoColors = length(Colors);

Ireduced = (I-min(I))/(max(I)-min(I))*(NoColors-1)+1;
RGB      = interp1(1:NoColors,Colors,Ireduced);

end

function drawtracks(tracks,header,mesh)
% IN PROGRESS - BAD CODE - DONT USE
%
% - Use trk_read from 'along-tract-stats' toolbox
%

hold on; clc;
All = [];

% put all tracks into a single matrix so we can fit a sphere
for iTrk = 1:length(tracks)
    if iTrk > 1; fprintf(repmat('\b',size(str))); end
    str = sprintf('Building volume for sphere fit (%d of %d)\n',iTrk,length(tracks));
    fprintf(str);
    
    matrix = tracks(iTrk).matrix;
    matrix(any(isnan(matrix(:,1:3)),2),:) = [];
    All = [All ; matrix];
end

% centre on 0 by subtracting sphere centre
iAll      = All;
iAll(:,1) = All(:,1)*-1;
iAll(:,2) = All(:,2)*-1;
Centre = spherefit(iAll);
maxpts = max(arrayfun(@(x) size(x.matrix, 1), tracks));

% Use minmax template vertices as bounds
MM(1,:) = min(mesh.vertices);
MM(2,:) = max(mesh.vertices);
MT(1,:) = min(iAll-repmat(Centre,[size(iAll,1),1]));
MT(2,:) = max(iAll-repmat(Centre,[size(iAll,1),1]));

pullback = min(MM(:,2)) - min(MT(:,2));
pullup   = max(MM(:,3)) - max(MT(:,3));

D = mean((MM)./MT);

% this time draw the tracks
for iTrk = 1:length(tracks)
    matrix = tracks(iTrk).matrix;
    matrix(any(isnan(matrix(:,1:3)),2),:) = [];
    
    matrix(:,1) = matrix(:,1)*-1; % flip L-R
    matrix(:,2) = matrix(:,2)*-1; % flip F-B
    M           = matrix - repmat(Centre,[size(matrix,1),1]); % centre
    M           = M.*repmat(D,[size(M,1),1]);
    M(:,2)      = M(:,2) + (pullback*1.1);                          % pullback
    M(:,3)      = M(:,3) + (pullup*1.1);                            % pull up

    h = patch([M(:,1)' nan], [M(:,2)' nan], [M(:,3)' nan], 0);
    cdata = [(0:(size(matrix, 1)-1))/(maxpts) nan];
    set(h,'cdata', cdata, 'edgecolor','interp','facecolor','none');
end

h = get(gcf,'Children');
set(h,'visible','off');

end


function overlay(mesh,L,write,fname,colbar,pos)
% Functional overlay plotter
%
% mesh is the gifti / patch
% L is the overlay (90,1)
% write is boolean flag
% fname is filename is write = 1;
%


% interp shading between nodes or just use mean value?
%-------------------------------------------------------------------
interpl = 1; 

% Overlay
v  = pos;                       % sourcemodel vertices
x  = v(:,1);                    % AAL x verts
mv = mesh.vertices;             % brain mesh vertices
nv = length(mv);                % number of brain vertices
OL = sparse(length(L),nv);      % this will be overlay matrix we average
r = (nv/length(pos))*1.3;       % radius - number of closest points on mesh
w  = linspace(.1,1,r);          % weights for closest points
w  = fliplr(w);                 % 
M  = zeros( length(x), nv);     % weights matrix: size(len(mesh),len(AAL))
S  = [min(L(:)),max(L(:))];     % min max values


% if overlay,L, is same length as mesh verts, just plot!
%-------------------------------------------------------------------
if length(L) == length(mesh.vertices)
    fprintf('Overlay already fits mesh! Plotting...\n');
    
    % spm mesh smoothing
    fprintf('Smoothing overlay...\n');
    y = spm_mesh_smooth(mesh, double(L(:)), 4);
    hh = get(gca,'children');
    set(hh(end),'FaceVertexCData',y(:),'FaceColor','interp');
    drawnow;
    shading interp
    colormap('jet');
    
    if colbar
        drawnow; pause(.5);
        colorbar('peer',gca,'South');
    end
    
    if write;
        fprintf('Writing overlay gifti file: %s\n',[fname 'Overlay.gii']);
        g       = gifti;
        g.cdata = double(y);
        g.private.metadata(1).name  = 'SurfaceID';
        g.private.metadata(1).value = [fname 'Overlay.gii'];
        save(g, [fname  'Overlay.gii']);
    end
    return
end




% otherwise find closest points (assume both in mm)
%-------------------------------------------------------------------
fprintf('Determining closest points between sourcemodel & template vertices\n');

for i = 1:length(x)
        
    % reporting
    if i > 1; fprintf(repmat('\b',[size(str)])); end
    str = sprintf('%d/%d',i,(length(x)));
    fprintf(str);
    
    % find closest point[s] in cortical mesh
    dist       = cdist(mv,v(i,:));
    [junk,ind] = maxpoints(dist,r,'min');
    OL(i,ind)  = w*L(i);
    M (i,ind)  = w;
    
end
fprintf('\n');

if ~interpl
     % mean value of a given vertex
    OL = mean((OL),1);
else
    for i = 1:size(OL,2)
        % average overlapping voxels
        L(i) = sum( OL(:,i) ) / length(find(OL(:,i))) ;
    end
    OL = L;
end


% normalise and rescale
y  = S(1) + ((S(2)-S(1))).*(OL - min(OL))./(max(OL) - min(OL));

y(isnan(y)) = 0;
y  = full(y);

% spm mesh smoothing
%-------------------------------------------------------------------
fprintf('Smoothing overlay...\n');
y = spm_mesh_smooth(mesh, y(:), 4);
hh = get(gca,'children');
set(hh(end),'FaceVertexCData',y(:),'FaceColor','interp');
drawnow;
shading interp
colormap('jet');

if colbar
    drawnow; pause(.5);
    colorbar('peer',gca,'South');    
end
    
if write;
    fprintf('Writing overlay gifti file: %s\n',[fname 'Overlay.gii']);
    g       = gifti;
    g.cdata = double(y);
    g.private.metadata(1).name  = 'SurfaceID';
    g.private.metadata(1).value = [fname 'Overlay.gii'];
    save(g, [fname  'Overlay.gii']);
end
    
end





function x = killinterhems(x);

S  = size(x);
xb = (S(1)/2)+1:S(1);
yb = (S(2)/2)+1:S(2);
xa = 1:S(1)/2;
ya = 1:S(2)/2;

x(xa,yb) = 0;
x(xb,ya) = 0;

end




function newpos = fixmesh(g,pos)
% plot as transparent grey gifti surface
%
% AS

v = g.vertices;
v = v - repmat(spherefit(v),[size(v,1),1]); % Centre on ~0
g.vertices=v;

% Centre on ~0
pos = pos - repmat(spherefit(pos),[size(pos,1),1]);

for i = 1:length(pos)
    this = pos(i,:);
    [t,I] = maxpoints(cdist(v,this),1,'max');
    newpos(i,:) = v(I,:);
end

end

function g = meshmesh(g,write,fname,fighnd,a,pos);

if isempty(a);
    a = .6;
end

% centre and scale mesh
v = g.vertices;
V = v - repmat(spherefit(v),[size(v,1),1]);

m = min(pos);
M = max(pos);

V(:,1)   = m(1) + ((M(1)-m(1))).*(V(:,1) - min(V(:,1)))./(max(V(:,1)) - min(V(:,1)));
V(:,2)   = m(2) + ((M(2)-m(2))).*(V(:,2) - min(V(:,2)))./(max(V(:,2)) - min(V(:,2)));
V(:,3)   = m(3) + ((M(3)-m(3))).*(V(:,3) - min(V(:,3)))./(max(V(:,3)) - min(V(:,3)));

g.vertices = V;

% plot
if ~isempty(fighnd)
    if isnumeric(fighnd)
        % Old-type numeric axes handle
        h = plot(fighnd,gifti(g));
    elseif ishandle(fighnd)
        % new for matlab2017b etc
        % [note editted gifti plot function]
        h = plot(gifti(g),'fighnd',fighnd);
    end
else
    h = plot(gifti(g));
end
C = [.5 .5 .5];

set(h,'FaceColor',[C]); box off;
grid off;  set(h,'EdgeColor','none');
alpha(a); set(gca,'visible','off');

h = get(gcf,'Children');
set(h(end),'visible','off');
drawnow;

if write;
    fprintf('Writing mesh gifti file: %s\n',[fname '.gii']);
    g = gifti(g);
    save(g,fname);
end


end

function addlabels(V,pos,all_roi_tissueindex,thelabels)
% Add labels to the plot.
%
% If using AAL90 sourcemodle, these are automatic.
%
% If using another sourcemodel:
% - provide the all_roi_tissueindex from fieldtirp. This is a
% 1xnum_vertices vector containing indices of rois (i,e. which verts belong
% to which rois).
% Also provide labels!
%

if ( ~isempty(thelabels) && ~isempty(all_roi_tissueindex) ) &&...
   ( length(pos) == length(all_roi_tissueindex) ) &&...
   ( length(thelabels) == length(unique(all_roi_tissueindex)) )
    
    labels = strrep(thelabels,'_',' ');
    v      = get_roi_centres(pos,all_roi_tissueindex);
    roi    = all_roi_tissueindex;
    
elseif length(V) == 90
    load('AAL_labels');
    labels = strrep(labels,'_',' ');
    v      = pos*0.9;
    roi    = 1:90;
else
    fprintf('Labels info not right!\n');
    return
end

% compile list of in-use node indices
%------------------------------------
to = []; from = []; 
for i  = 1:size(V,1)
    ni = find(logical(V(i,:)));
    if any(ni)
        to   = [to   roi(ni)];
        from = [from roi(repmat(i,[1,length(ni)])) ];
    end
end

AN  = unique([to,from]);
off = 1.5;

% add these to plot with offset
%------------------------------------
for i = 1:length(AN)
    L = labels{AN(i)};
    switch L(end)
        case 'L';
            t(i) = text(v(AN(i),1)-(off*5),v(AN(i),2)-(off*5),v(AN(i),3)+off,L);
        case 'R';
            t(i) = text(v(AN(i),1)+(off*2),+v(AN(i),2)+(off*2),v(AN(i),3)+off,L);
    end
end
set(t,'Fontsize',14)

end

function [C,verts] = get_roi_centres(pos,all_roi_tissueindex)
% Find centre points of rois
%
%
v   = pos;
roi = all_roi_tissueindex;

i   = unique(roi);
i(find(i==0))=[];

fprintf('Finding centre points of ROIs for labels...');
for j = 1:length(i)
    vox    = find(roi==i(j));
    verts{j}  = v(vox,:);
    C(j,:) = spherefit(verts{j});
end
fprintf('  ... done! \n');
% % Plot the first roi, mark centre and label:
% scatter3(v(:,1),v(:,2),v(:,3),'k'); hold on
% scatter3(verts(:,1),verts(:,2),verts(:,3),'r')
% scatter3(C(:,1),C(:,2),C(:,3),'b*')

end

function Centre = spherefit(X)
% Fit sphere to centre of vertices, return centre points
%
%

A =  [mean(X(:,1).*(X(:,1)-mean(X(:,1)))), ...
    2*mean(X(:,1).*(X(:,2)-mean(X(:,2)))), ...
    2*mean(X(:,1).*(X(:,3)-mean(X(:,3)))); ...
    0, ...
    mean(X(:,2).*(X(:,2)-mean(X(:,2)))), ...
    2*mean(X(:,2).*(X(:,3)-mean(X(:,3)))); ...
    0, ...
    0, ...
    mean(X(:,3).*(X(:,3)-mean(X(:,3))))];
A = A+A.';
B = [mean((X(:,1).^2+X(:,2).^2+X(:,3).^2).*(X(:,1)-mean(X(:,1))));...
     mean((X(:,1).^2+X(:,2).^2+X(:,3).^2).*(X(:,2)-mean(X(:,2))));...
     mean((X(:,1).^2+X(:,2).^2+X(:,3).^2).*(X(:,3)-mean(X(:,3))))];
Centre=(A\B).';
end


function video(mesh,L,colbar,fpath,tv,pos)
%

% OPTIONS
%-------------------------------------------------------------------
num         = 1;   % number of brains, 1 or 2
interpl     = 1;   % interpolate
brainview   = 'T'; % [T]op, [L]eft or [R]ight
videolength = 10;  % length in seconds
extendvideo = 4;   % smooth/extend video by factor of



% Extend and temporally smooth video by linear interp between points
%-------------------------------------------------------------------
if extendvideo > 0
    fprintf('Extending and smoothing video sequence by linear interpolation\n');
    time  = tv;
    for i = 1:size(L,1)
        dL(i,:) = interp(L(i,:),4);
    end
    L  = dL;
    tv = linspace(time(1),time(end),size(L,2));
end

% Overlay
%-------------------------------------------------------------------
v  = pos;
x  = v(:,1);                    % AAL x verts
mv = mesh.vertices;             % brain mesh vertices
nv = length(mv);                % number of brain vertices
ntime = size(L,2);
OL = zeros(size(L,1),nv,ntime); % this will be overlay matrix we average
r  = 1200;                      % radius - number of closest points on mesh
r  = (nv/length(pos))*1.3;
w  = linspace(.1,1,r);          % weights for closest points
w  = fliplr(w);                 % 
M  = zeros( length(x), nv);     % weights matrix: size(len(mesh),len(AAL))
S  = [min(L)',max(L)'];

% find closest points (assume both in mm)
%-------------------------------------------------------------------------
fprintf('Determining closest points between sourcemodel & template vertices\n');
for i = 1:length(x)

    % reporting
    if i > 1; fprintf(repmat('\b',[size(str)])); end
    str = sprintf('%d/%d',i,(length(x)));
    fprintf(str);    

    % find closest point[s] in cortical mesh
    dist       = cdist(mv,v(i,:));
    [junk,ind] = maxpoints(dist,r,'min');
    OL(i,ind,:)= w'*L(i,:);
    M (i,ind)  = w;  
    
end
fprintf('\n');

if ~interpl
    OL = mean((OL),1); % mean value of a given vertex
else
    fprintf('Averaging local & overlapping vertices (wait...)');
    for i = 1:size(OL,2)
        for j = 1:size(OL,3)
            % average overlapping voxels 
            L(i,j) = sum( OL(:,i,j) ) / length(find(OL(:,i,j))) ;
        end
    end
    fprintf(' ...Done\n');
    OL = L;
end

% normalise and rescale
for i = 1:size(OL,2)
    this = OL(:,i);
    y(:,i)  = S(i,1) + ((S(i,2)-S(i,1))).*(this - min(this))./(max(this) - min(this));
end

y(isnan(y)) = 0;
y  = full(y);

% spm mesh smoothing
fprintf('Smoothing overlay...\n');
for i = 1:ntime
    y(:,i) = spm_mesh_smooth(mesh, double(y(:,i)), 4);
end

% close image so can reopen with subplots
if num == 2;
    close
    f  = figure;
    set(f, 'Position', [100, 100, 2000, 1000])
    h1 = subplot(121);
    h2 = subplot(122);
else
    switch brainview
        case 'T'; bigimg;view(0,90);
        case 'R'; bigimg;view(90,0);  
        case 'L'; bigimg;view(270,0); 
    end
    f = gcf;
end

% MAKE THE GRAPH / VIDEO
%-----------------------------------------------------------------------
try    vidObj   = VideoWriter(fpath,'MPEG-4');          % CHANGE PROFILE
catch  vidObj   = VideoWriter(fpath,'Motion JPEG AVI');
end

set(vidObj,'Quality',100);
set(vidObj,'FrameRate',size(y,2)/(videolength));
open(vidObj);

for i = 1:ntime
    
    if i > 1; fprintf(repmat('\b',[1 length(str)])); end
    str = sprintf('building: %d of %d\n',i,ntime);
    fprintf(str);
    
    switch num
        case 2
            plot(h1,gifti(mesh));
            hh       = get(h1,'children');
            set(hh(end),'FaceVertexCData',y(:,i), 'FaceColor','interp');    
            shading interp
            view(270,0);
            caxis([min(S(:,1)) max(S(:,2))]);
            material dull
            camlight left 

            plot(h2,gifti(mesh));
            hh       = get(h2,'children');
            set(hh(3),'FaceVertexCData',y(:,i), 'FaceColor','interp');    
            shading interp
            view(90,0);
            caxis([min(S(:,1)) max(S(:,2))]);
            material dull
            camlight right 
        
        case 1
            hh = get(gca,'children');
            set(hh(end),'FaceVertexCData',y(:,i), 'FaceColor','interp');
            caxis([min(S(:,1)) max(S(:,2))]);
            shading interp
    end
    
    try
        tt = title(num2str(tv(i)),'fontsize',20);
        P = get(tt,'Position') ;
        P = P/max(P(:));
        set(tt,'Position',[P(1) P(2)+70 P(3)]) ;
    end
    
    set(findall(gca, 'type', 'text'), 'visible', 'on');
    
    if colbar
        colorbar
    end
    drawnow;
            
              

    currFrame = getframe(f);
    writeVideo(vidObj,currFrame);
end
close(vidObj);


    
end
















% Notes / Workings
%---------------------------------------------------
    %rotations - because x is orientated backward?
%     t  = 90;
%     Rx = [ 1       0       0      ;
%            0       cos(t) -sin(t) ;
%            0       sin(t)  cos(t) ];
%     Ry = [ cos(t)  0      sin(t)  ;
%            0       1      0       ;
%           -sin(t)  0      cos(t)  ];
%     Rz = [ cos(t) -sin(t) 0       ;
%            sin(t)  cos(t) 0       ;
%            0       0      1       ];
   %M = (Rx*(M'))';
   %M = (Ry*(M'))';
   %M = (Rz*(M'))';

   
