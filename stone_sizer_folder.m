function stone_sizer_folder(folder, fileprefix, samples)

    mkdir(strcat('output/', folder));
    for i = 1 : samples
        files = {};
        for j = 0: 5
           name = strcat(folder, '/', fileprefix, num2str(i), '_', num2str(j));
           fullPath = strcat(name, '.JPG');
           if (exist(fullPath, 'file') == 2)
                files = [files, {name}];
           end
        end
        fprintf(1, '%s - ', files{:})
        fprintf(1, '\n')
        [measurements]= stone_sizer(files);  

        lastRowStr = num2str(size(measurements,1) +1);
        export = {'ID' 'Length (mm)' 'Width (mm)' 'Area (mm^2)' 'U/2'};
        export = [export; measurements];
        
        stats = {'MIN U / 2' strcat('=MIN(E2:E', lastRowStr ,')') '' '' ''};
        stats = [stats; {'MAX U / 2' strcat('=MAX(E2:E', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'AVG U / 2' strcat('=AVERAGE(E2:E', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'MEDIAN U / 2' strcat('=MEDIAN(E2:E', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'STDEV U / 2' strcat('=STDEV(E2:E', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'VAR U / 2' strcat('=VAR(E2:E', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'' '' '' '' ''}];
        stats = [stats; {'MAX A' strcat('=MAX(D2:D', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'MIN A' strcat('=MIN(D2:D', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'AVG A' strcat('=AVERAGE(D2:D', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'MEDIAN A' strcat('=MEDIAN(D2:D', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'STDEV A' strcat('=STDEV(D2:D', lastRowStr ,')') '' '' ''}];
        stats = [stats; {'VAR A' strcat('=VAR(D2:D', lastRowStr ,')') '' '' ''}];


        xlswrite('output/summary.xls', export, num2str(i));
        xlswrite('output/summary.xls', stats, num2str(i), 'H2:J14');
    end
end