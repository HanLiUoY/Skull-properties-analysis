function [v_4_sdr,v_3_sdr,v_2_sdr,th_4_sdr,th_3_sdr,th_2_sdr,th_sdr,...
    rho_4_sdr,rho_3_sdr,rho_2_sdr,line_thickness,line_density_ratio,distance, line_hu]=calculate_skull_propeties(skull2center,x1)
   

distance=zeros(size(x1,1),1);
line_density_ratio=zeros(size(x1,1),1);
line_thickness=zeros(size(x1,1),1);
line_density_all=zeros(size(x1,1),1);
rho_4_sdr=zeros(size(x1,1),1);
rho_3_sdr=zeros(size(x1,1),1);
rho_2_sdr=zeros(size(x1,1),1);

v_4_sdr=zeros(size(x1,1),1);
v_3_sdr=zeros(size(x1,1),1);
v_2_sdr=zeros(size(x1,1),1);

th_4_sdr=zeros(size(x1,1),1);
th_3_sdr=zeros(size(x1,1),1);
th_2_sdr=zeros(size(x1,1),1);

th_sdr=zeros(size(x1,1),1);
line_hu=zeros(size(x1,1),1);

for i=1:size(x1,1)
    line_density=skull2center(i,:);
    n=1;
    %     if size(find(line_density>4900 & line_density<=5000),2)~=0 && size(find(line_density>5000),2)~=0 && find(line_density>5000,1,"first")-find(line_density>4900 & line_density<=5000,1,'last')>50
    %         line_density=seed2center(i,find(line_density>4900 & line_density<=5000,n,'first')+10:end);
    %distance(i)=find(line_density./max(line_density)==1,n,'first')-find(line_density>=1300,n,'first');
    %     else
    %         distance(i)=0;
    %     end
    %line_density=line_density(find(line_density>1000,n,'first'):end);
    %line_density=line_density(1:find(line_density==0,n,'first')-1);

    distance(i)=find(line_density./max(line_density)==1,n,'first')-find(line_density>1300,n,'first');
    % line_density=line_density(find(line_density>1300,n,'first'):end);
    % for in-vivo skull
    % line_density=line_density(1:find(line_density<1100,n,'first')-1);
    % for ex-vivo skull
    line_density=line_density(1:end-50);
    line_density(line_density==0)=1;

    line_density=line_density(find(line_density>1400,n,'first'):end);
    line_density=line_density(1:find(line_density>300,n,'last'));

    
    for j=1:length(line_density)
        if any(line_density)
            if line_density(end)<1000
                line_density=line_density(1:end-1);
            else
                break
            end
        end
    end

    distance(i)=distance(i)-2;%round(length(line_density)/2);
    %line_density=line_density(1:find(line_density<1000,n,'last')-1);
    line_density_all(i,1:size(line_density,2))=line_density;
    %line_mass_density(=line_density
    %line_density_ratio(p1,p2)=min(line_density(3:end-3))/max(line_density(2:end-2));
    line_density=line_density';
    line_hu(i,1)=mean(line_density);
    if sum(line_density)~=0

        % if the pixel depth larger than 8, corresponding to 5mm
        % thick the skull was devided to three sections:
        % cort_1: outer cortical layer, threshold: cort_1>0.7*cort_1
        % cortical_2: inne rcortical layer, threshold: cort_2>
        % 0.7*cort_2. note that not compare with cort_1
        % , trab_1: middle trabecular layer
        % the HU density at the air-bone boundary is lower than the
        % actual value due to the resolution limit, these boundary
        % values have changed to the maximum HU density value as they
        % should be.

        if length(line_density)>8
            cort_1=line_density(1:find(line_density./min(line_density(3:end-2))==1,1,'first'));
            cort_2=line_density(find(line_density./min(line_density(3:end-2))==1,1,'first')+1:end);

            cort_1_x=line_density(1:find(cort_1>max(cort_1)*0.8,1,'last'));%-1
            cort_1_x(1:find((cort_1_x)./max(cort_1_x)==1))=max(cort_1_x);

            %cort_2_x=line_density(find(cort_2>max(cort_2)*0.8,1,'first')+length(cort_1_x)+1:end);
            %cort_2_x(find((cort_2_x)./max(cort_2_x)==1):end)=max(cort_2_x);
            %trab_1=line_density(length(cort_1_x)+1:length(line_density)-length(cort_2_x));

            cort_2_x=line_density(find(cort_2>max(cort_2)*0.8,1,'first')+length(cort_1):end);
            cort_2_x(find((cort_2_x)./max(cort_2_x)==1):end)=max(cort_2_x);
            if length(cort_2_x)+length(cort_1_x)<length(line_density)
                trab_1=line_density(length(cort_1_x)+1:length(line_density)-length(cort_2_x));
            else
                if length(cort_1_x)>4
                    trab_1=cort_1_x(end);
                    cort_1_x=cort_1_x(1:end-1);
                else
                    trab_1=cort_2_x(1);
                    cort_1_x=cort_1_x(2:end);
                end
            end



            % cort_1=line_density(1:find(line_density./min(line_density(3:end-2))==1,1,'first'));
            % cort_2=line_density(find(line_density./min(line_density(3:end-2))==1,1,'first')+1:end);
            %
            % cort_1_x=line_density(1:find(cort_1./max(cort_1)==1,1,'last'));
            % cort_1_x(1:find((cort_1_x)./max(cort_1_x)==1))=max(cort_1_x);
            %
             %cort_2_x=line_density(find(cort_2./max(cort_2)==1,1,'first')+length(cort_1):end);
             %cort_2_x(find((cort_2_x)./max(cort_2_x)==1):end)=max(cort_2_x);
             %trab_1=line_density(length(cort_1_x)+1:length(line_density)-length(cort_2_x));

            % if the HU density contrast in the pixel depth is less than 20%,
            % the sections is manually segmented by 50% cort_1, 30% cort_2, and 20% trab_1
            if min(line_density(3:end-2))>max(line_density)*0.8
                cort_1_x =  line_density(1:round(length(line_density)/2)-1);
                cort_1_x(1:find((cort_1_x)./max(cort_1_x)==1))=max(cort_1_x);
                cort_2_x =  line_density(end-round(length(line_density)/3):end);
                cort_2_x(find((cort_2_x)./max(cort_2_x)==1):end)=max(cort_2_x);
                trab_1   =  line_density(length(cort_1_x)+1:(end-length(cort_2_x)));
            end
        end

        % if the pixel depth between 5-8, corresponding to ~2-4mm
        % skull segmented to pixel 1:2 to cort_1, last 1:2 to
        % cort_2, middle to trab_1
        if length(line_density)<=8 && length(line_density)>=5
            cort_1_x=line_density(1:2);
            cort_1_x(1:2)=max(cort_1_x);
            cort_2_x=line_density(end-1:end);
            cort_2_x(1:2)=max(cort_2_x);
            trab_1=line_density(3:end-2);
            if max(cort_1_x)<max(trab_1)
                cort_1_x(1:2)=max(trab_1);
            end
            if max(cort_2_x)<max(trab_1)
                cort_2_x(1:2)=max(trab_1);
            end

        end
        % if the pixel depth is less than 5, corresponding to less
        % than 2mm thick, the pixel values changed to the maximum
        % value with no contrast.
        if length(line_density)<5
            if length(line_density)<4
                cort_1_x=max(line_density);
                trab_1=max(line_density);
                cort_2_x=max(line_density);
                distance(i)=distance(i)+0;
            end

            if length(line_density)==4
                cort_1_x(1:2)=max(line_density);
                trab_1=max(line_density);
                cort_2_x=max(line_density);
            end
            
        end
        %angle(p1,p2)=asind(sqrt((p1-55)^2+(p2-55)^2)/170);

        % changing the HU unit to the mass density information
        [cort_out_d cort_out_v]=hounsfield2density(cort_1_x);
        [trab_d trab_v]=hounsfield2density(trab_1);
        [cort_inn_d cort_inn_v]=hounsfield2density(cort_2_x);
        % calculate the mean layer density
        rho_4_sdr(i,1)=max(cort_out_d);
        rho_3_sdr(i,1)=min(trab_d);
        rho_2_sdr(i,1)=max(cort_inn_d);
        if rho_4_sdr(i,1)<rho_2_sdr(i,1)
            rho_4_sdr(i,1)=rho_2_sdr(i,1);
        end

        %rho_4_sdr=rho_4_sdr.*1.0;
        %rho_3_sdr=rho_3_sdr.*1.0;
        %rho_2_sdr=rho_2_sdr.*1.0;

        v_4_sdr(i,1)=rho_4_sdr(i,1).*1.048+654;
        v_3_sdr(i,1)=rho_3_sdr(i,1).*1.048+654;
        v_2_sdr(i,1)=rho_2_sdr(i,1).*1.048+654;
        th_4_sdr(i,1)=(length(cort_out_d));%*0.44*1e-3;
        th_3_sdr(i,1)=(length(trab_d));%*0.44*1e-3;
        th_2_sdr(i,1)=(length(cort_inn_d));%*0.44*1e-3;
        th_sdr(i,1)=th_2_sdr(i,1)+th_3_sdr(i,1)+th_4_sdr(i,1);


    end


    %
    if sum(line_density,'all')==0 || size(line_density,1)<1 || size(find(line_density>1000),1)<1 %3|| mean(line_density)<1000 
        line_thickness(i)=0;
        line_density_ratio(i)=0;
        distance(i)=0;
    else

        %line_thickness(i)=find(line_density>1000,n,'last')-find(line_density>1000,n,'first')+1;
        line_thickness(i)=length(line_density);
        %if min(line_density(find(line_density>1000,n,'first'):find(line_density>1000,n,'last')))<100
        if min(line_density(:))<100
            line_density_ratio(i)=100/(max(line_density(find(line_density>1000,n,'first'):find(line_density>1000,n,'last')))-1000);
        else
            % line_density_ratio(i)=(min(line_density(find(line_density>1000,n,'first')+1:find(line_density>1000,n,'last')-1))-1000)...
            %     /(max(line_density(find(line_density>1000,n,'first'):find(line_density>1000,n,'last')))-1000);
            line_density_ratio(i)=min(trab_1)/max([max(cort_1_x) max(cort_2_x)]);
        end
    end
end

clear cort_1 cort_1_x cort_2 cort_2_x cort_inn_d cort_inn_v cort_out_d cort_out_v trab_1 trab_d trab_v