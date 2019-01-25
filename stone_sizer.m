function[measurements] = stone_sizer(filenames)

% Threshold to create a black/white image out of the gray k-mean output
BW_THRESHOLD = 0.15;

% Number of colors to detect in the image (fixed to background and objects)
K_COLORS = 2;

% Defines the sizes in mm of the reference object
REF_OBJECT_WIDTH = 85.6;
REF_OBJECT_HEIGHT = 54;


REF_OBJECT_ASPECT_DELTA = 0.24;
REF_OBJECT_ASPECT_RATIO = REF_OBJECT_WIDTH / REF_OBJECT_HEIGHT;

measurements = {};
for fi = 1: numel(filenames)
filename = cellstr(filenames(fi));
filename = filename{1};
filename = strcat(filename, '.jpg');

% Read the original image and scale it down
orig_image = imread(filename);
scaled_image =  imresize(orig_image, 0.5);

[parentDir] = fileparts(filename);
mkdir(strcat('output/', parentDir));

%scaled_image = orig_image;

% Convert RGB (Red Green Blue) to L*a*b (also known as CIELAB)
% LAB allows for easy differentiation of colors ignoring variations in
% their brightness (L* - luminosity, a* red-green axis, b* blue-yellow
% axis). Differences in color can be measured using the Euclidean distance 
% between a* and b* coordinates.
% Starting in Matlab R2014b use built-in rgb2lab instead.
lab_image = RGB2Lab(scaled_image);

% Extract a* / b* and converts it into a usable matrix. 
ab = lab_image(:,:,2:3);
nrows = size(ab,1);
ncols = size(ab,2);
ab = reshape(ab,nrows*ncols,2);

% repeat the clustering 3 times to avoid local minima
[cluster_idx, cluster_center] = kmeans(ab,K_COLORS,'distance','sqEuclidean', ...
                                      'Replicates',3);
                                  
pixel_labels = reshape(cluster_idx,nrows,ncols);

segmented_images = cell(1,3);
rgb_label = repmat(pixel_labels,[1 1 3]);

for k = 1:K_COLORS
    color = scaled_image;
    color(rgb_label ~= k) = 0;
    segmented_images{k} = color;
end

% Need to detect which of the segmented images is the one with the
% background (has more color than the other)
meanRGB1 = mean(reshape(segmented_images{1}, [], 3), 1);
meanRGB2 = mean(reshape(segmented_images{2}, [], 3), 1);


if (meanRGB1(1) > meanRGB2(1))
    used_seg_image = segmented_images{1};
else
    used_seg_image = segmented_images{2};
end

figure(1);
imshow(segmented_images{1});
imwrite(segmented_images{1}, strcat('output/', filename, '_seg1.jpg'));

figure(2);
imshow(segmented_images{2});
imwrite(segmented_images{2}, strcat('output/', filename, '_seg2.jpg'));


bw = im2bw(used_seg_image, BW_THRESHOLD);
bw_i = ~bw;

figure(3);
imshow(bw_i);
imwrite(bw_i, strcat('output/', filename, '_bw.jpg'));

s = regionprops(bw_i, {'Centroid', 'BoundingBox', 'Area', 'ConvexHull', 'FilledArea', 'Orientation'});
figure(4);
imshow(scaled_image)
hold on
numObj = numel(s);

fprintf('Class: %s\n', class(s));

largestArea = 0;
brightestArea = 0;
for k = 1 : numObj    
    [rx,ry,area] = minboundrect(s(k).ConvexHull(:,1), s(k).ConvexHull(:,2));
    [width, height] = measure(rx,ry);
    aspect = max(width, height) / min(width, height);
    aspect_delta = abs(REF_OBJECT_ASPECT_RATIO - aspect);
    area = width * height;
    
    topLeftX = round(s(k).BoundingBox(1));
    topLeftY = round(s(k).BoundingBox(2));
    boundingWidth = max(0,round(s(k).BoundingBox(3))-2);
    boundingHeight = max(0,round(s(k).BoundingBox(4))-2);

    objectCut = scaled_image(topLeftY:topLeftY+boundingHeight, topLeftX:topLeftX+boundingWidth, :);
    brightness = round(sum(mean(reshape(objectCut, [], 3), 1)));
    
    % fprintf('Found object with aspect %4.2f and delta %4.2f as %d - orientation %4.2f and brightness %d\n', aspect, aspect_delta, k, s(k).Orientation, brightness);
    if (aspect_delta < REF_OBJECT_ASPECT_DELTA && area > largestArea && abs(s(k).Orientation) < 15 && brightness > brightestArea) 
        fprintf('Found ref object with delta %4.2f as %d\n', aspect_delta, k);
        refObjectId = k;
        largestArea = area;
        brightestArea = brightness;
    end
end

%objId = 0;
%leftPos = 100000000;
%rightPos = 100000000;
%foundObjId = -1;
%for k = 1 : numObj
%    if (s(k).Area > 50)
%        objId = objId + 1;
%        if (s(k).Centroid(1) < leftPos && s(k).Centroid(2) < rightPos)
%            leftPos = s(k).Centroid(1);
%            rightPos = s(k).Centroid(2);
%            foundObjId = objId;
%        end
%    end
%end



[rx,ry,area] = minboundrect(s(refObjectId).ConvexHull(:,1), s(refObjectId).ConvexHull(:,2));
[width, height] = measure(rx,ry);

mm_per_pixel_width = REF_OBJECT_WIDTH / width;
mm_per_pixel_height = REF_OBJECT_HEIGHT / height;
mm_per_pixel_area = mm_per_pixel_width * mm_per_pixel_height;



foundObjId = refObjectId;
objId = 0;
userObjId = 0;


for k = 1 : numObj
    
    [rx,ry,area] = minboundrect(s(k).ConvexHull(:,1), s(k).ConvexHull(:,2));
    [widthPx, heightPx]= measure(rx, ry);
    widthMm = widthPx * mm_per_pixel_width;
    heightMm = heightPx * mm_per_pixel_height;
    objId = objId + 1;
    if ((widthMm >= 8 && heightMm >=2) || (heightMm >= 8 && widthMm >= 2))
        userObjId = userObjId + 1;
        %plot(s(k).Centroid(1), s(k).Centroid(2), 'bo');
        %text(s(k).Centroid(1),s(k).Centroid(2), sprintf('%2.1f', s(k).Area), 'EdgeColor','b','Color','r');
        %X = rot90(s(k).Extrema, -1);
        %c = minBoundingBox(X);
        %plot(c(1,[1:end 1]),c(2,[1:end 1]),'r')
        
        areaMm = s(k).FilledArea * mm_per_pixel_area;
        uHalf = widthMm + heightMm;
        if (userObjId > 1)
            measurements = [measurements; {strcat(filename, '-', num2str(userObjId)) widthMm heightMm areaMm uHalf}];
        end
        if (foundObjId == objId)
            plot(rx,ry,'r');
        else
             plot(rx,ry,'y');
        end
        
        X = s(k).ConvexHull;
        %plot(X(:,1),X(:,2),'.');
        text(s(k).Centroid(1),s(k).Centroid(2), sprintf('%d', userObjId), 'EdgeColor','b','BackgroundColor','w');
        %if (foundObjId == objId)
        %    rectangle('Position', s(k).BoundingBox, 'EdgeColor','b');
        %else
        %    rectangle('Position', s(k).BoundingBox, 'EdgeColor','b');
        %end
    end
end
hold off




%print(strcat('output/', filename, '_detected') ,'-dpng')
export_fig(strcat('output/', filename, '_detected.png'), '-a1');
%xlswrite(strcat('output/', filename, '.xls'), export);
end
end

function [width, height] = measure(rx, ry)
    refP = [rx(1); ry(1)];
    l = norm(refP - [rx(2); ry(2)]);
    l = [l; norm(refP - [rx(3); ry(3)])];
    l = [l; norm(refP - [rx(4); ry(4)])];

    l = sort(l);
    height = l(1);
    width = l(2);
end