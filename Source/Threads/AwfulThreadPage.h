//
//  AwfulThreadPage.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-12.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

typedef enum {
    // Not sure what the last page is, but you want it.
    AwfulThreadPageLast = -2,
    
    // The first page that has unread posts.
    AwfulThreadPageNextUnread = -1,
    
    /* Implicitly include values for 1 to n, where n is the number of pages in the thread. */
} AwfulThreadPage;
