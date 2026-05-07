function [skull_volume]=generate_skull_volume(skull_resized)
skull_region_volume=zeros(size(skull_resized));
%g is the skull region length:*0.44

for Z=1:size(skull_region_volume,3)
    skull_region=zeros(size(skull_region_volume,1),size(skull_region_volume,2));
    for g=1:size(skull_region_volume,2)
        %k is the field depth from top to bottom, eliminate the air
        %above the skull
        for k=1:size(skull_region_volume,1)
            %find the boundary of the skull outer surface :define as
            %between 1500-3000
            if skull_resized(k,g,Z)>1500 && skull_resized(k,g,Z)<3000
            %if skull_resized(k,g,Z)>1000 && skull_resized(k,g,Z)<3000
                %index the outer boundary to skull_region
                skull_region(k,g)=skull_resized(k,g,Z);
                break
            end
        end
        %l is the field depth from bottom to top, eliminate the air
        %below the skull
        for l=size(skull_resized,1):-1:1
            %find the ineer boundary of the skull:define as
            %between 1500-3000
            if skull_resized(l,g,Z)>1300 && skull_resized(l,g,Z)<3000
            %if skull_resized(l,g,Z)>1000 && skull_resized(l,g,Z)<3000
                skull_region(l,g)=skull_resized(l,g,Z);
                break
            end
        end
        %m is the distance between skull outer and inner boundary
        for m=k+1:l-1
            %add data to the region
            skull_region(m,g)=skull_resized(m,g,Z);
        end
        %n is the distance betwee skull outer and inner boundary,from
        %bottom to top, can change to 'find'
        %             for n=size(skull_region,1)-2:-1:1
        %                 if skull_region(n,y(1,1)+g-68)>3000
        %                     %skull_region(n,g)=skull_region(n+1,g);
        %                     % delete the marker and surrounding
        %                     skull_region(n-3:n+3,y(1,1)+g-68-3:y(1,1)+g-68+3)=0;
        %                 end
        %             end
    end
    %delete the attached remains, smooth surface
    %         for g2=1:size(skull_region,2)-2
    %             for n2=size(skull_region,1)-2:-1:1
    %                 if skull_region(n2+2,g2)==0 && skull_region(n2+1,g2)~=0 && skull_region(n2,g2)==0
    %                     skull_region(n2+1,g2)=0;
    %                 end
    %                 if skull_region(n2,g2)==0 && skull_region(n2,g2+1)~=0 && skull_region(n2,g2+2)==0
    %                     skull_region(n2,g2+1)=0;
    %                 end
    %             end
    %             if size(find(skull_region(:,g2)~=0),1)~=0 && size(find(skull_region(:,g2+1)~=0),1)~=0
    %                 if  size(find(skull_region(:,g2+1)~=0),1)-size(find(skull_region(:,g2)~=0),1)>5
    %                     skull_region((1:find(skull_region(:,g2)~=0,1)-1),g2+1)=0;
    %                 end
    %             end
    %         end
    % find the maximum depth for skull volume
    for i=size(skull_region,1):-1:1
        if any((skull_region(i,:)>2000))
            skull_region(i:end,:)=0;
            break
        else
            skull_region(i:end,:)=0;
        end
    end
    % trim off the ct bed comment it no bed
%     for i=1:size(skull_region,1)
%         %find(s_normal_3_2(:,p1,p2)>1000,1,"last");
%         skull_region(find(skull_region(:,i)>1300,1,"last")+1:end,i)=0;
%     end
    skull_region_volume(:,:,Z)=skull_region;
end
%% for elsa 
 %skull_volume=skull_region_volume;
% % delete empty volume
for i1=size(skull_region_volume,1):-1:1
    if sum(skull_region_volume(i1,:,:),"all")~=0
        break
    end
end
for i2=1:size(skull_region_volume,1)
    if sum(skull_region_volume(i2,:,:),"all")~=0
        break
    end
end
skull_volume=skull_region_volume(i2:i1,:,:);
%
for i1=size(skull_volume,2):-1:1
    if sum(skull_volume(:,i1,:),"all")~=0
        break
    end
end
for i2=1:size(skull_volume,2)
    if sum(skull_volume(:,i2,:),"all")~=0
        break
    end
end
skull_volume=skull_volume(:,i2:i1,:);
%
for i1=size(skull_volume,3):-1:1
    if sum(skull_volume(:,:,i1),"all")~=0
        break
    end
end
for i2=1:size(skull_volume,3)
    if sum(skull_volume(:,:,i2),"all")~=0
        break
    end
end
skull_volume=skull_volume(:,:,i2:i1);
if rem(size(skull_volume,1),2)~=0
    skull_volume(end+1,:,:)=zeros(size(skull_volume,2),size(skull_volume,3));
end
if rem(size(skull_volume,2),2)~=0
    skull_volume(:,end+1,:)=zeros(size(skull_volume,1),size(skull_volume,3));
end
if rem(size(skull_volume,3),2)~=0
    skull_volume(:,:,end+1)=zeros(size(skull_volume,1),size(skull_volume,2));
end









%%
clear skull_region_volume g m i1 i2 k l skull_region Z skull_resized
% find the center point
% assgin a center identifer to the skull_volume
% skull_volume(size(skull_volume,1)-2:size(skull_volume,1)+2, ...
%     round(0.5*size(skull_volume,2))-2:round(0.5*size(skull_volume,2))+2, ...
%     round(0.5*size(skull_volume,3))-2:round(0.5*size(skull_volume,3))+2)=6000;