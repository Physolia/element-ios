/*
 Copyright 2017 Vector Creations Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "RoomMembershipBubbleCell.h"

#import "RiotDesignValues.h"

#import "RoomBubbleCellData.h"

static CGFloat xibPictureViewTopConstraintConstant;

@implementation RoomMembershipBubbleCell

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.messageTextView.tintColor = kRiotColorGreen;

    // Get original xib value once
    if (xibPictureViewTopConstraintConstant == 0)
    {
        xibPictureViewTopConstraintConstant = self.pictureViewTopConstraint.constant;
    }
}

- (void)prepareForReuse
{
    if (self.pictureViewTopConstraint.constant != xibPictureViewTopConstraintConstant)
    {
        self.pictureViewTopConstraint.constant = xibPictureViewTopConstraintConstant;
    }
}

- (void)render:(MXKCellData *)cellData
{
    [super render:cellData];

    RoomBubbleCellData *data = (RoomBubbleCellData*)cellData;

    // If the text was moved down, do the same for the icon
    if (data.selectedComponentIndex != NSNotFound && [data.attributedTextMessage.string hasPrefix:@"\n"])
    {
        self.pictureViewTopConstraint.constant = xibPictureViewTopConstraintConstant + 14;
    }
}
@end
